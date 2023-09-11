// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {ERC20Votes} from "openzeppelin/token/ERC20/extensions/ERC20Votes.sol";
import {SafeCast} from "openzeppelin/utils/math/SafeCast.sol";

import {L2GovernorMetadata} from "src/WormholeL2GovernorMetadata.sol";
import {IL1Block} from "src/interfaces/IL1Block.sol";

/// @notice A contract to collect votes on L2 to be bridged to L1.
abstract contract L2VoteAggregator {
  /// @notice The number of blocks before L2 voting closes. We close voting 1200 blocks before the
  /// end of the proposal to cast the vote.
  uint32 public constant CAST_VOTE_WINDOW = 1200;

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

  /// @dev The voting options corresponding to those used in the Governor.
  enum VoteType {
    Against,
    For,
    Abstain
  }

  /// @dev Data structure to store vote preferences expressed by depositors.
  // TODO: Does it matter if we use a uint128 vs a uint256?
  struct ProposalVote {
    uint128 against;
    uint128 inFavor;
    uint128 abstain;
  }

  /// @notice A mapping of proposal to a mapping of voter address to boolean indicating whether a
  /// voter has voted or not.
  mapping(uint256 => mapping(address => bool)) private _proposalVotersHasVoted;

  /// @notice A mapping of proposal id to proposal vote totals.
  mapping(uint256 => ProposalVote) public proposalVotes;

  /// @dev Emitted when a vote is cast on L2.
  event VoteCast(address indexed voter, uint256 proposalId, uint8 support, uint256 weight);

  /// @param _votingToken The token used to vote on proposals.
  /// @param _governorMetadata The `GovernorMetadata` contract that provides proposal information.
  /// @param _l1BlockAddress The address of the L1Block contract.
  /// @param _sourceChain The chain sending the votes.
  /// @param _targetChain The target chain to bridge the votes to.
  constructor(
    address _votingToken,
    address _governorMetadata,
    address _l1BlockAddress,
    uint16 _sourceChain,
    uint16 _targetChain
  ) {
    VOTING_TOKEN = ERC20Votes(_votingToken);
    GOVERNOR_METADATA = L2GovernorMetadata(_governorMetadata);
    L1_BLOCK = IL1Block(_l1BlockAddress);
  }

  function initialize(address l1BridgeAddress) public {
    if (INITIALIZED) revert AlreadyInitialized();
    INITIALIZED = true;
    L1_BRIDGE_ADDRESS = l1BridgeAddress;
  }

  /// @notice Where a user can express their vote based on their L2 token voting power.
  /// @param proposalId The id of the proposal to vote on.
  /// @param support The type of vote to cast.
  function castVote(uint256 proposalId, uint8 support) public returns (uint256) {
    if (!proposalVoteActive(proposalId)) revert ProposalInactive();
    if (_proposalVotersHasVoted[proposalId][msg.sender]) revert AlreadyVoted();
    _proposalVotersHasVoted[proposalId][msg.sender] = true;

    L2GovernorMetadata.Proposal memory proposal = GOVERNOR_METADATA.getProposal(proposalId);
    uint256 weight = VOTING_TOKEN.getPastVotes(msg.sender, proposal.voteStart);
    if (weight == 0) revert NoWeight();

    if (support == uint8(VoteType.Against)) {
      proposalVotes[proposalId].against += SafeCast.toUint128(weight);
    } else if (support == uint8(VoteType.For)) {
      proposalVotes[proposalId].inFavor += SafeCast.toUint128(weight);
    } else if (support == uint8(VoteType.Abstain)) {
      proposalVotes[proposalId].abstain += SafeCast.toUint128(weight);
    } else {
      revert InvalidVoteType();
    }
    emit VoteCast(msg.sender, proposalId, support, weight);
    return weight;
  }

  /// @notice Bridges a vote to the L1.
  /// @param proposalId The id of the proposal to bridge.
  function bridgeVote(uint256 proposalId) external payable {
    if (!proposalVoteActive(proposalId)) revert ProposalInactive();

    ProposalVote memory vote = proposalVotes[proposalId];

    bytes memory proposalCalldata = abi.encode(proposalId, vote.against, vote.inFavor, vote.abstain);
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

  function proposalVoteActive(uint256 proposalId) public view returns (bool active) {
    L2GovernorMetadata.Proposal memory proposal = GOVERNOR_METADATA.getProposal(proposalId);

    // TODO: Check if this is inclusive
    return L1_BLOCK.number() <= internalVotingPeriodEnd(proposalId)
      && L1_BLOCK.number() >= proposal.voteStart;
  }
}
