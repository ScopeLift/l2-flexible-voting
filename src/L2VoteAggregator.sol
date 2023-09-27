// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20Votes} from "openzeppelin/token/ERC20/extensions/ERC20Votes.sol";
import {SafeCast} from "openzeppelin/utils/math/SafeCast.sol";
import {EIP712} from "openzeppelin/utils/cryptography/EIP712.sol";
import {ECDSA} from "openzeppelin/utils/cryptography/ECDSA.sol";

import {L2GovernorMetadata} from "src/WormholeL2GovernorMetadata.sol";
import {IL1Block} from "src/interfaces/IL1Block.sol";

/// @notice A contract to collect votes on L2 to be bridged to L1.
abstract contract L2VoteAggregator is EIP712 {
  /// @notice The number of blocks before L2 voting closes. We close voting 1200 blocks before the
  /// end of the proposal to cast the vote.
  uint32 public constant CAST_VOTE_WINDOW = 1200;

  bytes32 public constant BALLOT_TYPEHASH = keccak256("Ballot(uint256 proposalId,uint8 support)");

  /// @notice The token used to vote on proposals provided by the `GovernorMetadata`.
  ERC20Votes public immutable VOTING_TOKEN;

  /// @notice The `GovernorMetadata` contract that provides proposal information.
  L2GovernorMetadata public immutable GOVERNOR_METADATA;

  /// @notice The address of the bridge that receives L2 votes.
  address L1_BRIDGE_ADDRESS;

  /// @notice The contract that handles fetch the L1 block on the L2.
  IL1Block public immutable L1_BLOCK;

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
    Cancelled,
    Expired
  }

  /// @dev Data structure to store vote preferences expressed by depositors.
  // TODO: Does it matter if we use a uint128 vs a uint256?
  struct ProposalVote {
    uint128 againstVotes;
    uint128 forVotes;
    uint128 abstainVotes;
  }

  /// @notice A mapping of proposal to a mapping of voter address to boolean indicating whether a
  /// voter has voted or not.
  mapping(uint256 proposalId => mapping(address voterAddress => bool)) private
    _proposalVotersHasVoted;

  /// @notice A mapping of proposal id to proposal vote totals.
  mapping(uint256 proposalId => ProposalVote) public proposalVotes;

  /// @dev Emitted when a vote is cast on L2.
  event VoteCast(
    address indexed voter, uint256 proposalId, VoteType support, uint256 weight, string reason
  );

  /// @param _votingToken The token used to vote on proposals.
  /// @param _governorMetadata The `GovernorMetadata` contract that provides proposal information.
  /// @param _l1BlockAddress The address of the L1Block contract.
  constructor(address _votingToken, address _governorMetadata, address _l1BlockAddress)
    EIP712("L2VoteAggregator", "1")
  {
    VOTING_TOKEN = ERC20Votes(_votingToken);
    GOVERNOR_METADATA = L2GovernorMetadata(_governorMetadata);
    L1_BLOCK = IL1Block(_l1BlockAddress);
  }

  function initialize(address l1BridgeAddress) public {
    if (INITIALIZED) revert AlreadyInitialized();
    INITIALIZED = true;
    L1_BRIDGE_ADDRESS = l1BridgeAddress;
  }

  /// @notice This function does not make sense in the L2 context, but we have added it to have
  /// compatibility with existing Governor tooling.
  function votingDelay() public view virtual returns (uint256) {
    return 0;
  }

  /// @notice This function does not make sense in the L2 context, but we have added it to have
  /// compatibility with existing Governor tooling.
  function votingPeriod() public view virtual returns (uint256) {
    return 0;
  }

  /// @notice This function does not make sense in the L2 context, but we have added it to have
  /// compatibility with existing Governor tooling.
  function quorum(uint256) public view virtual returns (uint256) {
    return 0;
  }

  /// @notice This function does not make sense in the L2 context, but we have added it to have
  /// compatibility with existing Governor tooling.
  function proposalThreshold() public view virtual returns (uint256) {
    return 0;
  }

  // @notice Shows the state of of a proposal on L2. We only support a subset of the Governor
  // proposal states. If the vote has not started the state is pending, if voting has started it is
  // active, if it has been cancelled then the state is cancelled, and if the voting has finished
  // without it being cancelled we will mark it as expired. We use expired because users can no
  // longer vote and no other L2 action can be taken on the proposal.
  function state(uint256 proposalId) public view virtual returns (ProposalState) {
    L2GovernorMetadata.Proposal memory proposal = GOVERNOR_METADATA.getProposal(proposalId);
    if (VOTING_TOKEN.clock() < proposal.voteStart) return ProposalState.Pending;
    else if (proposalVoteActive(proposalId)) return ProposalState.Active;
    else if (proposal.isCancelled) return ProposalState.Cancelled;
    else return ProposalState.Expired;
  }

  /// @notice This function does not make sense in the L2 context, but we have added it to have
  /// compatibility with existing Governor tooling.
  function getVotes(address, uint256) public view virtual returns (uint256) {
    return 0;
  }

  /// @notice This function does not make sense in the L2 context, but we have added it to have
  /// compatibility with existing Governor tooling.
  function propose(address[] memory, uint256[] memory, bytes[] memory, string memory)
    public
    virtual
    returns (uint256)
  {
    revert UnsupportedMethod();
  }

  /// @notice This function does not make sense in the L2 context, but we have added it to have
  /// compatibility with existing Governor tooling.
  function execute(address[] memory, uint256[] memory, bytes[] memory, bytes32)
    public
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
    return _castVote(proposalId, msg.sender, support, "");
  }

  /// @notice Where a user can express their vote based on their L2 token voting power, and provide a reason.
  /// @param proposalId The id of the proposal to vote on.
  /// @param support The type of vote to cast.
  /// @param reason The reason the vote was cast.
  function castVoteWithReason(uint256 proposalId, VoteType support, string calldata reason)
    public
    virtual
    returns (uint256)
  {
    return _castVote(proposalId, msg.sender, support, reason);
  }

  /// @notice Where a user can express their vote based on their L2 token voting power using  a signature.
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
    return _castVote(proposalId, voter, support, "");
  }

  /// @notice Bridges a vote to the L1.
  /// @param proposalId The id of the proposal to bridge.
  function bridgeVote(uint256 proposalId) external payable {
    if (!proposalVoteActive(proposalId)) revert ProposalInactive();

    ProposalVote memory vote = proposalVotes[proposalId];

    bytes memory proposalCalldata =
      abi.encode(proposalId, vote.againstVotes, vote.forVotes, vote.abstainVotes);
    _bridgeVote(proposalCalldata);
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
    L2GovernorMetadata.Proposal memory proposal = GOVERNOR_METADATA.getProposal(proposalId);
    _lastVotingBlock = proposal.voteEnd - CAST_VOTE_WINDOW;
  }

  function _castVote(uint256 proposalId, address voter, VoteType support, string memory reason)
    internal
    returns (uint256)
  {
    if (!proposalVoteActive(proposalId)) revert ProposalInactive();
    if (_proposalVotersHasVoted[proposalId][voter]) revert AlreadyVoted();
    _proposalVotersHasVoted[proposalId][voter] = true;

    L2GovernorMetadata.Proposal memory proposal = GOVERNOR_METADATA.getProposal(proposalId);
    uint256 weight = VOTING_TOKEN.getPastVotes(voter, proposal.voteStart);
    if (weight == 0) revert NoWeight();

    if (support == VoteType.Against) {
      proposalVotes[proposalId].againstVotes += SafeCast.toUint128(weight);
    } else if (support == VoteType.For) {
      proposalVotes[proposalId].forVotes += SafeCast.toUint128(weight);
    } else if (support == VoteType.Abstain) {
      proposalVotes[proposalId].abstainVotes += SafeCast.toUint128(weight);
    } else {
      revert InvalidVoteType();
    }
    emit VoteCast(voter, proposalId, support, weight, reason);
    return weight;
  }

  function proposalVoteActive(uint256 proposalId) public view returns (bool active) {
    L2GovernorMetadata.Proposal memory proposal = GOVERNOR_METADATA.getProposal(proposalId);

    // TODO: Check if this is inclusive
    return L1_BLOCK.number() <= internalVotingPeriodEnd(proposalId)
      && L1_BLOCK.number() >= proposal.voteStart && !proposal.isCancelled;
  }
}
