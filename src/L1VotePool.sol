// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IGovernor} from "openzeppelin/governance/Governor.sol";
import {IWormhole} from "wormhole/interfaces/IWormhole.sol";

import {WormholeReceiver} from "src/WormholeReceiver.sol";

contract L1VotePool is WormholeReceiver {
  /// @notice Must call castVote within this many blocks of the proposal deadline, so-as to allow
  /// ample time for all depositors to express their vote preferences.
  uint32 public constant CAST_VOTE_WINDOW = 1200;

  /// @notice The address of the L1 Governor contract.
  IGovernor public governor;

  /// @dev Thrown when proposal does not exist.
  error MissingProposal();

  /// @dev Thrown when a proposal vote is invalid.
  error InvalidProposalVote();

  /// @dev Thrown when a vote is cast before the CAST_VOTE_WINDOW
  error OutsideOfWindow();

  /// @dev Contains the distribution of a proposal vote.
  struct ProposalVote {
    uint128 inFavor;
    uint128 against;
    uint128 abstain;
  }

  /// @notice A mapping of proposal id to the proposal vote distribution.
  mapping(uint256 => ProposalVote) public proposalVotes;

  /// @param _core The address of the Wormhole Core contract.
  /// @param _governor The address of the L1 Governor contract.
  constructor(address _core, address _governor) WormholeReceiver(_core) {
    governor = IGovernor(_governor);
  }

  /// @notice Receives a message from L2 and saves the proposal vote distribution.
  /// @param encodedMsg The encoded message Wormhole VAA from the L2.
  function receiveEncodedMsg(bytes memory encodedMsg) public override {
    (IWormhole.VM memory vm,,) = _validateMessage(encodedMsg);

    (uint256 proposalId, uint128 against, uint128 inFavor, uint128 abstain) =
      abi.decode(vm.payload, (uint256, uint128, uint128, uint128));

    ProposalVote memory existingProposalVote = proposalVotes[proposalId];
    if (
      existingProposalVote.against <= against || existingProposalVote.inFavor <= inFavor
        || existingProposalVote.abstain <= abstain
    ) revert InvalidProposalVote();

    bool proposalActive = proposalVoteActive(proposalId);
    if (!proposalActive) revert OutsideOfWindow();

    // Save proposal vote
    proposalVotes[proposalId] = ProposalVote(inFavor, against, abstain);
  }

  /// @notice Casts vote to the L1 Governor.
  /// @param proposalId The id of the proposal being cast.
  function castVote(uint256 proposalId) public {
    uint256 voteEnd = governor.proposalDeadline(proposalId);
    uint256 internalEnd = internalVotingPeriodEnd(proposalId);
    // TODO: Does a vote on on the block or the block after
    if (block.number <= internalEnd || block.number >= voteEnd) revert OutsideOfWindow();

    ProposalVote memory vote = proposalVotes[proposalId];
    if ((vote.against + vote.inFavor + vote.abstain) <= 0) revert MissingProposal();

    bytes memory votes = abi.encodePacked(vote.against, vote.inFavor, vote.abstain);

    // This param is ignored by the governor when voting with fractional
    // weights. It makes no difference what vote type this is.
    uint8 unusedSupportParam = uint8(1);

    // TODO: string should probably mention chain
    governor.castVoteWithReasonAndParams(
      proposalId, unusedSupportParam, "rolled-up vote from governance L2 token holders", votes
    );
  }

  /// @notice Method which returns the deadline for depositors to express their voting preferences
  /// to this Bridge contract. Will always be before the Governor's corresponding proposal deadline.
  /// @param proposalId The ID of the proposal.
  function internalVotingPeriodEnd(uint256 proposalId)
    public
    view
    returns (uint256 _lastVotingBlock)
  {
    _lastVotingBlock = governor.proposalDeadline(proposalId) - CAST_VOTE_WINDOW;
  }

  /// @notice Whether a proposal is still active to receive a vote from the L1Pool.
  /// @notice proposalId The id of the proposal.
  function proposalVoteActive(uint256 proposalId) public view returns (bool active) {
    uint256 internalEnd = internalVotingPeriodEnd(proposalId);
    uint256 votingStart = governor.proposalSnapshot(proposalId);
    return block.number < internalEnd && block.number >= votingStart;
  }
}