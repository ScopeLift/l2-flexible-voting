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
  /// end of the proposal to cast the vote. We will allow another 1200 blocks to allow for the final
  /// vote total to be sent to the L1.
  uint32 public constant CAST_VOTE_WINDOW = 2400;

  /// @notice The Wormhole contract to bridge messages to L1.
  IWormhole coreBridge;

  /// @notice A unique number used to send messages.
  uint32 public nonce;

  /// @notice The token used to vote on proposals provided by the `GovernorMetadata`.
  ERC20Votes votingToken;

  /// @notice The `GovernorMetadata` contract that provides proposal information.
  L2GovernorMetadata governorMetadata;

  /// @notice The contract that handles fetch the L1 block on the L2.
  IL1Block l1Block;

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
    votingToken = ERC20Votes(_votingToken);
    coreBridge = IWormhole(_core);
    governorMetadata = L2GovernorMetadata(_governorMetadata);
    nonce = 0;
    l1Block = IL1Block(l1BlockAddress);
  }

  /// @notice Where a user can express their vote based on their L2 token voting power.
  /// @param proposalId The id of the proposal to vote on.
  /// @param support The type of vote to cast.
  function expressVote(uint256 proposalId, uint8 support) external {
    bool proposalActive = proposalVoteActive(proposalId);
    if (!proposalActive) revert ProposalInactive();

    L2GovernorMetadata.Proposal memory proposal = governorMetadata.getProposal(proposalId);
    uint256 weight = votingToken.getPastVotes(msg.sender, proposal.voteStart);
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
  }

  /// @notice Bridges a vote to the L1.
  /// @param proposalId The id of the proposal to bridge.
  function bridgeVote(uint256 proposalId) external payable returns (uint64 sequence) {
    bool proposalActive = proposalVoteActive(proposalId);
    if (!proposalActive) revert ProposalInactive();

    ProposalVote memory vote = proposalVotes[proposalId];

    bytes memory proposalCalldata =
      abi.encodePacked(proposalId, vote.against, vote.inFavor, vote.abstain);
    sequence = coreBridge.publishMessage(nonce, proposalCalldata, 1);
    nonce = nonce + 1;
    return sequence;
  }

  /// @notice Method which returns the deadline for token holders to express their voting
  /// preferences to this Aggregator contract. Will always be before the Governor's corresponding
  /// proposal deadline.
  /// @param proposalId The ID of the proposal.
  function internalVotingPeriodEnd(uint256 proposalId)
    public
    view
    returns (uint256 _lastVotingBlock)
  {
    L2GovernorMetadata.Proposal memory proposal = governorMetadata.getProposal(proposalId);
    _lastVotingBlock = proposal.voteEnd - CAST_VOTE_WINDOW;
  }

  function proposalVoteActive(uint256 proposalId) public view returns (bool active) {
    L2GovernorMetadata.Proposal memory proposal = governorMetadata.getProposal(proposalId);

    // TODO: Check if this is inclusive
    return l1Block.number() <= internalVotingPeriodEnd(proposalId)
      && l1Block.number() >= proposal.voteStart;
  }
}
