// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {IWormhole} from "wormhole/interfaces/IWormhole.sol";
import {WormholeReceiver} from "src/WormholeReceiver.sol";

/// @notice Receives L1 messages with proposal metadata.
contract L2GovernorMetadata is WormholeReceiver {
  /// @notice The L1 proposal metadata.
  struct Proposal {
    uint256 voteStart;
    uint256 voteEnd;
  }

  ///@notice The id of the proposal mapped to the proposal metadata.
  mapping(uint256 => Proposal) _proposals;

  /// @param _relayer The address of the Wormhole relayer contract.
  constructor(address _relayer) WormholeReceiver(_relayer) {}

  /// @notice Receives a message from L1 and saves the proposal metadata.
  /// @param payload The payload that was sent to in the delivery request.
  function receiveEncodedMsg(bytes memory payload, bytes[] memory, bytes32, uint16, bytes32)
    public
    override
    onlyRelayer
  {
    (uint256 proposalId, uint256 voteStart, uint256 voteEnd) =
      abi.decode(payload, (uint256, uint256, uint256));

    _proposals[proposalId] = Proposal(voteStart, voteEnd);
  }

  /// @notice Returns the proposal metadata for a given proposal id.
  /// @param proposalId The id of the proposal.
  function getProposal(uint256 proposalId) public view virtual returns (Proposal memory) {
    return _proposals[proposalId];
  }
}
