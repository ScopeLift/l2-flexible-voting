// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Strings.sol";
import {IL1Block} from "src/interfaces/IL1Block.sol";

/// @notice This contract is used by an `L2VoteAggregator` to store proposal metadata.
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

  /// @notice The assumed block time of the base network
  uint256 private L1_BLOCK_TIME = 12;
  /// @notice The assumed block time of the target network
  /// @dev These are hardcoded now for Ethereum mainnet & Optimism, as these are currently
  /// the target networks for the MVP launch. In the future, this should be generalized to work
  /// for different network combinations. Even better, once we have better support for cross chain
  /// voting in clients and frontend tools, this hack should removed completely.
  uint256 private L2_BLOCK_TIME = 2;

  /// @notice The contract that handles fetching the L1 block on the L2.
  /// @dev If the block conversion hack is removed from this contract, then this storage var is
  /// probably not needed in this contract and can probably be moved back to the `L2VoteAggregator`
  IL1Block public immutable L1_BLOCK;

  /// @notice The number of blocks on L1 before L2 voting closes. We close voting 1200 blocks
  // before the end of the proposal to cast the vote.
  /// @dev If the block conversion hack is removed from this contract, then this storage var is
  /// probably not needed in this contract and can probably be moved back to the `L2VoteAggregator`
  uint32 public immutable CAST_VOTE_WINDOW;

  error PastBlockNumber();

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

  /// @param _l1BlockAddress The address of the L1Block contract.
  constructor(address _l1BlockAddress, uint32 _castWindow) {
    L1_BLOCK = IL1Block(_l1BlockAddress);
    CAST_VOTE_WINDOW = _castWindow;
  }

  /// @notice Add proposal to internal storage.
  /// @param proposalId The id of the proposal.
  /// @param voteStart The base chain block number when voting starts.
  /// @param voteEnd The base chain block number when voting ends.
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
        block.number,
        _l2BlockForFutureL1Block(voteEnd - CAST_VOTE_WINDOW),
        string.concat("Mainnet proposal ", Strings.toString(proposalId))
      );
    }
  }

  /// @notice Returns the proposal metadata for a given proposal id.
  /// @param proposalId The id of the proposal.
  function getProposal(uint256 proposalId) public view virtual returns (Proposal memory) {
    return _proposals[proposalId];
  }

  /// @notice Calculate the approximate block that the L2 will be producing at the time the
  /// L1 produces some given future block number.
  /// @param _l1BlockNumber The number of a future L1 block
  /// @return The approximate block number the L2 will be producing when L1 produces the given
  /// block
  function _l2BlockForFutureL1Block(uint256 _l1BlockNumber) internal view returns (uint256) {
    // We should never send an L1 block in the past. If we did, this would overflow & revert.
    if (_l1BlockNumber < L1_BLOCK.number()) revert PastBlockNumber();
    uint256 _l1BlocksUntilEnd = _l1BlockNumber - L1_BLOCK.number();

    return block.number + ((_l1BlocksUntilEnd * L1_BLOCK_TIME) / L2_BLOCK_TIME);
  }
}
