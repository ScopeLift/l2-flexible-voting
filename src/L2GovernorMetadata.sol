// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {IWormhole} from "wormhole/interfaces/IWormhole.sol";
import {WormholeReceiver} from "src/WormholeReceiver.sol";
/// @dev Contract is already initialized with an L2 token.

error AlreadyInitialized();

/// @notice Receives L1 messages with proposal metadata.
contract L2GovernorMetadata is WormholeReceiver {
  /// @notice The L1 proposal metadata.
  struct Proposal {
    uint256 voteStart;
    uint256 voteEnd;
  }

  /// @notice The id of the proposal mapped to the proposal metadata.
  mapping(uint256 => Proposal) _proposals;

  /// @param _core The address of the Wormhole core contract.
  constructor(address _core) WormholeReceiver(_core) {}

  /// @notice Receives a message from L1 and saves the proposal metadata.
  /// @param encodedMsg The encoded message Wormhole VAA from the L1.
  function receiveEncodedMsg(bytes memory encodedMsg) public override {
    (IWormhole.VM memory vm,,) = _validateMessage(encodedMsg);

    (uint256 proposalId, uint256 voteStart, uint256 voteEnd) =
      abi.decode(vm.payload, (uint256, uint256, uint256));

    _proposals[proposalId] = Proposal(voteStart, voteEnd);
  }

  /// @notice Returns the proposal metadata for a given proposal id.
  /// @param proposalId The id of the proposal.
  function getProposal(uint256 proposalId) public view returns (Proposal memory) {
    return _proposals[proposalId];
  }
}
