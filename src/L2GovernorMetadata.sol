// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

/// @notice Receives L1 messages with proposal metadata.
abstract contract L2GovernorMetadata {
  /// @notice The L1 proposal metadata.
  struct Proposal {
    uint256 voteStart;
    uint256 voteEnd;
  }

  /// @notice The id of the proposal mapped to the proposal metadata.
  mapping(uint256 => Proposal) _proposals;

  /// @notice Add proposal to internal storage.
  /// @dev We expect this method to be called by the L1GovernorMetadata bridge.
  /// @param proposalId The id of the proposal.
  /// @param voteStart The block number or timestamp when voting starts.
  /// @param voteEnd The block number or timestamp when voting ends.
  function _addProposal(uint256 proposalId, uint256 voteStart, uint256 voteEnd) internal virtual {
    _proposals[proposalId] = Proposal(voteStart, voteEnd);
  }

  /// @notice Returns the proposal metadata for a given proposal id.
  /// @param proposalId The id of the proposal.
  function getProposal(uint256 proposalId) public view virtual returns (Proposal memory) {
    return _proposals[proposalId];
  }
}
