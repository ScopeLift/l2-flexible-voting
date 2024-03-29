// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20Votes} from "openzeppelin/token/ERC20/extensions/ERC20Votes.sol";
import {SafeCast} from "openzeppelin/utils/math/SafeCast.sol";
import {EIP712} from "openzeppelin/utils/cryptography/EIP712.sol";
import {ECDSA} from "openzeppelin/utils/cryptography/ECDSA.sol";

import {L2GovernorMetadata} from "src/WormholeL2GovernorMetadata.sol";
import {L2CountingFractional} from "src/L2CountingFractional.sol";

/// @notice A contract to collect votes on L2 to be bridged to L1.
abstract contract L2VoteAggregator is EIP712, L2GovernorMetadata, L2CountingFractional {
  bytes32 public constant BALLOT_TYPEHASH = keccak256("Ballot(uint256 proposalId,uint8 support)");

  /// @notice The token used to vote on proposals provided by the `GovernorMetadata`.
  ERC20Votes public immutable VOTING_TOKEN;

  /// @notice The address of the bridge that receives L2 votes.
  address public L1_BRIDGE_ADDRESS;

  /// @notice Used to indicate whether the contract has been initialized with the L1 bridge address.
  bool public INITIALIZED = false;

  /// @dev Thrown when an address has no voting weight on a proposal.
  error NoWeight();

  /// @dev Thrown when an address has already voted.
  error AlreadyVoted();

  /// @dev Thrown when an invalid vote is cast.
  error InvalidVoteType();

  /// @dev Thrown when proposal is inactive.
  error ProposalInactive();

  /// @dev Contract is already initialized with an L2 token.
  error AlreadyInitialized();

  /// @dev We do not support the method, but provide it to be compatible with 3rd party tooling.
  error UnsupportedMethod();

  /// @dev The voting options corresponding to those used in the Governor.
  enum VoteType {
    Against,
    For,
    Abstain
  }

  /// @dev The states of a proposal on L2.
  enum ProposalState {
    Pending,
    Active,
    Canceled,
    INVALID_Defeated,
    INVALID_Succeeded,
    INVALID_Queued,
    Expired,
    INVALID_Executed
  }

  /// @notice A mapping of proposal to a mapping of voter address to boolean indicating whether a
  /// voter has voted or not.
  mapping(uint256 proposalId => mapping(address voterAddress => bool)) private
    _proposalVotersHasVoted;

  /// @dev Emitted when a vote is cast on L2.
  event VoteCast(
    address indexed voter, uint256 proposalId, uint8 support, uint256 weight, string reason
  );

  /**
   * @dev Emitted when a vote is cast with params.
   *
   * Note: `support` values should be seen as buckets. Their interpretation depends on the voting
   * module used.
   * `params` are additional encoded parameters. Their interpepretation also depends on the voting
   * module used.
   */
  event VoteCastWithParams(
    address indexed voter,
    uint256 proposalId,
    uint8 support,
    uint256 weight,
    string reason,
    bytes params
  );

  event VoteBridged(
    uint256 indexed proposalId, uint256 voteAgainst, uint256 voteFor, uint256 voteAbstain
  );

  /// @param _votingToken The token used to vote on proposals.
  constructor(address _votingToken) EIP712("L2VoteAggregator", "1") {
    VOTING_TOKEN = ERC20Votes(_votingToken);
  }

  function initialize(address l1BridgeAddress) public {
    if (INITIALIZED) revert AlreadyInitialized();
    INITIALIZED = true;
    L1_BRIDGE_ADDRESS = l1BridgeAddress;
  }

  /// @notice This function does not make sense in the L2 context, but we have added it to have
  /// compatibility with existing Governor tooling.
  function votingDelay() external view virtual returns (uint256) {
    return 0;
  }

  /// @notice This function does not make sense in the L2 context, but we have added it to have
  /// compatibility with existing Governor tooling.
  function votingPeriod() external view virtual returns (uint256) {
    return 0;
  }

  /// @notice This function does not make sense in the L2 context, but we have added it to have
  /// compatibility with existing Governor tooling.
  function quorum(uint256) external view virtual returns (uint256) {
    return 0;
  }

  /// @notice This function does not make sense in the L2 context, but we have added it to have
  /// compatibility with existing Governor tooling.
  function proposalThreshold() external view virtual returns (uint256) {
    return 0;
  }

  // @notice Shows the state of of a proposal on L2. We only support a subset of the Governor
  // proposal states. If the vote has not started the state is pending, if voting has started it is
  // active, if it has been canceled then the state is canceled, and if the voting has finished
  // without it being canceled we will mark it as expired. We use expired because users can no
  // longer vote and no other L2 action can be taken on the proposal.
  function state(uint256 proposalId) external view virtual returns (ProposalState) {
    L2GovernorMetadata.Proposal memory proposal = getProposal(proposalId);
    if (VOTING_TOKEN.clock() < proposal.voteStart) return ProposalState.Pending;
    else if (proposalL2VoteActive(proposalId)) return ProposalState.Active;
    else if (proposal.isCanceled) return ProposalState.Canceled;
    else return ProposalState.Expired;
  }

  /// @notice This function does not make sense in the L2 context because it requires an L2 block as
  /// the second parameter rather than an L1 block. We added it to have
  /// compatibility with existing Governor tooling.
  function getVotes(address, uint256) external view virtual returns (uint256) {
    return 0;
  }

  /// @notice This function does not make sense in the L2 context, but we have added it to have
  /// compatibility with existing Governor tooling.
  function propose(address[] memory, uint256[] memory, bytes[] memory, string memory)
    external
    virtual
    returns (uint256)
  {
    revert UnsupportedMethod();
  }

  /// @notice This function does not make sense in the L2 context, but we have added it to have
  /// compatibility with existing Governor tooling.
  function execute(address[] memory, uint256[] memory, bytes[] memory, bytes32)
    external
    payable
    virtual
    returns (uint256)
  {
    revert UnsupportedMethod();
  }

  /// @notice Where a user can express their vote based on their L2 token voting power.
  /// @param proposalId The id of the proposal to vote on.
  /// @param support The type of vote to cast.
  function castVote(uint256 proposalId, VoteType support) public returns (uint256) {
    return _castVote(proposalId, msg.sender, uint8(support), "");
  }

  /// @notice Where a user can express their vote based on their L2 token voting power, and provide
  /// a reason.
  /// @param proposalId The id of the proposal to vote on.
  /// @param support The type of vote to cast.
  /// @param reason The reason the vote was cast.
  function castVoteWithReason(uint256 proposalId, VoteType support, string calldata reason)
    public
    virtual
    returns (uint256)
  {
    return _castVote(proposalId, msg.sender, uint8(support), reason);
  }

  function castVoteWithReasonAndParams(
    uint256 proposalId,
    uint8 support,
    string calldata reason,
    bytes memory params
  ) public virtual returns (uint256) {
    return _castVote(proposalId, msg.sender, support, reason, params);
  }

  /// @notice Where a user can express their vote based on their L2 token voting power using  a
  /// signature.
  /// @param proposalId The id of the proposal to vote on.
  /// @param support The type of vote to cast.
  function castVoteBySig(uint256 proposalId, VoteType support, uint8 v, bytes32 r, bytes32 s)
    public
    virtual
    returns (uint256)
  {
    address voter = ECDSA.recover(
      _hashTypedDataV4(keccak256(abi.encode(BALLOT_TYPEHASH, proposalId, support))), v, r, s
    );
    return _castVote(proposalId, voter, uint8(support), "");
  }

  /// @notice Bridges a vote to the L1.
  /// @param proposalId The id of the proposal to bridge.
  function bridgeVote(uint256 proposalId) external payable {
    if (!proposalL1VoteActive(proposalId)) revert ProposalInactive();

    (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) = proposalVotes(proposalId);

    bytes memory proposalCalldata = abi.encode(proposalId, againstVotes, forVotes, abstainVotes);
    _bridgeVote(proposalCalldata);
    emit VoteBridged(proposalId, againstVotes, forVotes, abstainVotes);
  }

  function _bridgeVote(bytes memory proposalCalldata) internal virtual;

  /// @notice Method which returns the deadline for token holders to express their voting
  /// preferences to this Aggregator contract. Will always be before the Governor's corresponding
  /// proposal deadline.
  /// @param proposalId The ID of the proposal.
  /// @return _lastVotingBlock the voting block where L2 voting ends.
  function internalVotingPeriodEnd(uint256 proposalId)
    public
    view
    returns (uint256 _lastVotingBlock)
  {
    L2GovernorMetadata.Proposal memory proposal = getProposal(proposalId);
    _lastVotingBlock = proposal.voteEnd - CAST_VOTE_WINDOW;
  }

  function _castVote(uint256 proposalId, address account, uint8 support, string memory reason)
    internal
    virtual
    returns (uint256)
  {
    return _castVote(proposalId, account, support, reason, "");
  }

  function _castVote(
    uint256 proposalId,
    address account,
    uint8 support,
    string memory reason,
    bytes memory params
  ) internal virtual returns (uint256) {
    if (!proposalL2VoteActive(proposalId)) revert ProposalInactive();

    L2GovernorMetadata.Proposal memory proposal = getProposal(proposalId);
    uint256 weight = VOTING_TOKEN.getPastVotes(account, proposal.voteStart);
    if (weight == 0) revert NoWeight();
    _countVote(proposalId, account, support, weight, params);

    if (params.length == 0) emit VoteCast(account, proposalId, support, weight, reason);
    else emit VoteCastWithParams(account, proposalId, support, weight, reason, params);

    return weight;
  }

  function proposalL2VoteActive(uint256 proposalId) public view returns (bool active) {
    L2GovernorMetadata.Proposal memory proposal = getProposal(proposalId);

    return L1_BLOCK.number() <= internalVotingPeriodEnd(proposalId)
      && L1_BLOCK.number() >= proposal.voteStart && !proposal.isCanceled;
  }

  function proposalL1VoteActive(uint256 proposalId) public view returns (bool active) {
    L2GovernorMetadata.Proposal memory proposal = getProposal(proposalId);

    return L1_BLOCK.number() <= proposal.voteEnd && L1_BLOCK.number() >= proposal.voteStart
      && !proposal.isCanceled;
  }
}
