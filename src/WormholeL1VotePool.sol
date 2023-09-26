// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {L1VotePool} from "src/L1VotePool.sol";

contract WormholeL1VotePool is L1VotePool {
  /// @param _governor The address of the L1 Governor contract.
  constructor(address _governor) L1VotePool(_governor) {}

  /// @notice Receives a message from L2 and saves the proposal vote distribution.
  /// @param payload The payload that was sent to in the delivery request.
  function _receiveCastVoteWormholeMessages(
    bytes memory payload,
    bytes[] memory,
    bytes32,
    uint16,
    bytes32
  ) internal {
    (uint256 proposalId, uint128 againstVotes, uint128 forVotes, uint128 abstainVotes) =
      abi.decode(payload, (uint256, uint128, uint128, uint128));

    ProposalVote memory existingProposalVote = proposalVotes[proposalId];
    if (
      existingProposalVote.againstVotes > againstVotes || existingProposalVote.forVotes > forVotes
        || existingProposalVote.abstainVotes > abstainVotes
    ) revert InvalidProposalVote();

    // Save proposal vote
    proposalVotes[proposalId] = ProposalVote(againstVotes, forVotes, abstainVotes);

    _castVote(
      proposalId,
      ProposalVote(
        againstVotes - existingProposalVote.againstVotes,
        forVotes - existingProposalVote.forVotes,
        abstainVotes - existingProposalVote.abstainVotes
      )
    );
  }
}
