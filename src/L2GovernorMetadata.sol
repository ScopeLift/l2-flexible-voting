// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice This contract is used by an L2VoteAggregator to store proposal metadata.
/// It expects to receive proposal metadata from a valid L1 source.
/// Derived contracts are responsible for processing and validating incoming metadata.
abstract contract L2GovernorMetadata {
  /// @notice Matches schema of L1 proposal metadata.
  struct Proposal {
    uint256 voteStart;
    uint256 voteEnd;
    bool isCanceled;
  }

  /// @notice The id of the proposal mapped to the proposal metadata.
  mapping(uint256 proposalId => Proposal) _proposals;

  event ProposalAdded(
    uint256 indexed proposalId, uint256 voteStart, uint256 voteEnd, bool isCanceled
  );

  /// @notice Add proposal to internal storage.
  /// @param proposalId The id of the proposal.
  /// @param voteStart The block number or timestamp when voting starts.
  /// @param voteEnd The block number or timestamp when voting ends.
  function _addProposal(uint256 proposalId, uint256 voteStart, uint256 voteEnd, bool isCanceled)
    internal
    virtual
  {
    _proposals[proposalId] = Proposal(voteStart, voteEnd, isCanceled);
    emit ProposalAdded(proposalId, voteStart, voteEnd, isCanceled);
  }

  /// @notice Returns the proposal metadata for a given proposal id.
  /// @param proposalId The id of the proposal.
  function getProposal(uint256 proposalId) public view virtual returns (Proposal memory) {
    return _proposals[proposalId];
  }
}
