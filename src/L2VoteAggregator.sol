// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {ERC20Votes} from "openzeppelin/token/ERC20/extensions/ERC20Votes.sol";
import {SafeCast} from "openzeppelin/utils/math/SafeCast.sol";
import {IWormhole} from "wormhole/interfaces/IWormhole.sol";

import {L2GovernorMetadata} from "src/L2GovernorMetadata.sol";
import {IL1Block} from "src/interfaces/IL1Block.sol";

/// @notice A contract to collect votes on L2 to be bridged to L1.
contract L2VoteAggregator {
  /// @notice The number of blocks before L2 voting closes. We close voting 1200 blocks before the
  /// end of the proposal to cast the vote.
  uint32 public constant CAST_VOTE_WINDOW = 1200;

  /// @notice The Wormhole contract to bridge messages to L1.
  IWormhole immutable CORE_BRIDGE;

  /// @notice A unique number used to send messages.
  uint32 public nonce;

  /// @notice The token used to vote on proposals provided by the `GovernorMetadata`.
  ERC20Votes immutable VOTING_TOKEN;

  /// @notice The `GovernorMetadata` contract that provides proposal information.
  L2GovernorMetadata immutable GOVERNOR_METADATA;

  /// @notice The contract that handles fetch the L1 block on the L2.
  IL1Block immutable L1_BLOCK;

  /// @dev Thrown when an address has no voting weight on a proposal.
  error NoWeight();

  /// @dev Thrown when an address has already voted.
  error AlreadyVoted();

  /// @dev Thrown when an invalid vote is cast.
  error InvalidVoteType();

  /// @dev Thrown when proposal is inactive.
  error ProposalInactive();

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

  /// @param _votingToken The token used to vote on proposals.
  /// @param _core The Wormhole contract to bridge messages to L1.
  /// @param _governorMetadata The `GovernorMetadata` contract that provides proposal information.
  /// @param l1BlockAddress The address of the L1Block contract.
  constructor(
    address _votingToken,
    address _core,
    address _governorMetadata,
    address l1BlockAddress
  ) {
    VOTING_TOKEN = ERC20Votes(_votingToken);
    CORE_BRIDGE = IWormhole(_core);
    GOVERNOR_METADATA = L2GovernorMetadata(_governorMetadata);
    L1_BLOCK = IL1Block(l1BlockAddress);
  }

  /// @notice Where a user can express their vote based on their L2 token voting power.
  /// @param proposalId The id of the proposal to vote on.
  /// @param support The type of vote to cast.
  function castVote(uint256 proposalId, uint8 support) public returns (uint256 balance) {
    bool proposalActive = proposalVoteActive(proposalId);
    if (!proposalActive) revert ProposalInactive();

    L2GovernorMetadata.Proposal memory proposal = GOVERNOR_METADATA.getProposal(proposalId);
    uint256 weight = VOTING_TOKEN.getPastVotes(msg.sender, proposal.voteStart);
    if (weight == 0) revert NoWeight();

    if (_proposalVotersHasVoted[proposalId][msg.sender]) revert AlreadyVoted();

    _proposalVotersHasVoted[proposalId][msg.sender] = true;
    if (support == uint8(VoteType.Against)) {
      proposalVotes[proposalId].against += SafeCast.toUint128(weight);
    } else if (support == uint8(VoteType.For)) {
      proposalVotes[proposalId].inFavor += SafeCast.toUint128(weight);
    } else if (support == uint8(VoteType.Abstain)) {
      proposalVotes[proposalId].abstain += SafeCast.toUint128(weight);
    } else {
      revert InvalidVoteType();
    }
    return weight;
  }

  /// @notice Bridges a vote to the L1.
  /// @param proposalId The id of the proposal to bridge.
  /// @return sequence The id of the of the message sent through Wormhole.
  function bridgeVote(uint256 proposalId) external payable returns (uint64 sequence) {
    bool proposalActive = proposalVoteActive(proposalId);
    if (!proposalActive) revert ProposalInactive();

    ProposalVote memory vote = proposalVotes[proposalId];

    bytes memory proposalCalldata =
      abi.encodePacked(proposalId, vote.against, vote.inFavor, vote.abstain);
    sequence = CORE_BRIDGE.publishMessage(nonce, proposalCalldata, 1);
    nonce = nonce + 1;
    return sequence;
  }

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
