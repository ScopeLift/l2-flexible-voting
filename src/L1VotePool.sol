// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IGovernor} from "openzeppelin/governance/Governor.sol";
import {IWormhole} from "wormhole/interfaces/IWormhole.sol";

import {WormholeReceiver} from "src/WormholeReceiver.sol";

abstract contract L1VotePool is WormholeReceiver {
  /// @notice The address of the L1 Governor contract.
  IGovernor public governor;

  /// @dev Thrown when proposal does not exist.
  error MissingProposal();

  /// @dev Thrown when a proposal vote is invalid.
  error InvalidProposalVote();

  /// @dev Contains the distribution of a proposal vote.
  struct ProposalVote {
    uint128 inFavor;
    uint128 against;
    uint128 abstain;
  }

  /// @notice A mapping of proposal id to the proposal vote distribution.
  mapping(uint256 => ProposalVote) public proposalVotes;

  /// @param _relayer The address of the Wormhole Relayer.
  /// @param _governor The address of the L1 Governor contract.
  constructor(address _relayer, address _governor) WormholeReceiver(_relayer) {
    governor = IGovernor(_governor); }

  /// @notice Receives a message from L2 and saves the proposal vote distribution.
  /// @param payload The payload that was sent to in the delivery request.
  function _receiveCastVoteWormholeMessages(
    bytes memory payload,
    bytes[] memory,
    bytes32,
    uint16,
    bytes32
  ) internal {
    (uint256 proposalId, uint128 against, uint128 inFavor, uint128 abstain) =
      abi.decode(payload, (uint256, uint128, uint128, uint128));

    ProposalVote memory existingProposalVote = proposalVotes[proposalId];
    if (
      existingProposalVote.against > against || existingProposalVote.inFavor > inFavor
        || existingProposalVote.abstain > abstain
    ) revert InvalidProposalVote();

    // Save proposal vote
    proposalVotes[proposalId] = ProposalVote(inFavor, against, abstain);

    _castVote(
      proposalId,
      ProposalVote(
        inFavor - existingProposalVote.inFavor,
        against - existingProposalVote.against,
        abstain - existingProposalVote.abstain
      )
    );
  }

  /// @notice Casts vote to the L1 Governor.
  /// @param proposalId The id of the proposal being cast.
  function _castVote(uint256 proposalId, ProposalVote memory vote) internal {
    bytes memory votes = abi.encodePacked(vote.against, vote.inFavor, vote.abstain);

    // This param is ignored by the governor when voting with fractional
    // weights. It makes no difference what vote type this is.
    uint8 unusedSupportParam = uint8(1);

    // TODO: string should probably mention chain
    governor.castVoteWithReasonAndParams(
      proposalId, unusedSupportParam, "rolled-up vote from governance L2 token holders", votes
    );
  }
}
