// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Strings.sol";

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

  event ProposalCreated(
    uint256 proposalId,
    address proposer,
    address[] targets,
    uint256[] values,
    string[] signatures,
    bytes[] calldatas,
    uint256 startBlock,
    uint256 endBlock,
    string description
  );

  event ProposalCanceled(uint256 proposalId);

  /// @notice Add proposal to internal storage.
  /// @param proposalId The id of the proposal.
  /// @param voteStart The block number or timestamp when voting starts.
  /// @param voteEnd The block number or timestamp when voting ends.
  /// @param isCanceled Whether or not the proposal has been canceled.
  function _addProposal(uint256 proposalId, uint256 voteStart, uint256 voteEnd, bool isCanceled)
    internal
    virtual
  {
    _proposals[proposalId] = Proposal(voteStart, voteEnd, isCanceled);
    if (isCanceled) {
      emit ProposalCanceled(proposalId);
    } else {
      emit ProposalCreated(
        proposalId,
        address(0),
        new address[](0),
        new uint256[](0),
        new string[](0),
        new bytes[](0),
        voteStart,
        voteEnd,
        string.concat("Mainnet proposal ", Strings.toString(proposalId))
      );
    }
  }

  /// @notice Returns the proposal metadata for a given proposal id.
  /// @param proposalId The id of the proposal.
  function getProposal(uint256 proposalId) public view virtual returns (Proposal memory) {
    return _proposals[proposalId];
  }
}
