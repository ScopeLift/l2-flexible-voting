// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {WormholeReceiver} from "src/WormholeReceiver.sol";
import {WormholeBase} from "src/WormholeBase.sol";
import {L2GovernorMetadata} from "src/L2GovernorMetadata.sol";

/// @notice Use Wormhole to receive L1 proposal metadata.
contract WormholeL2GovernorMetadata is L2GovernorMetadata, WormholeReceiver {
  /// @param _relayer The address of thWormholeL2GovernorMetadata contract.
  constructor(address _relayer) WormholeBase(_relayer) L2GovernorMetadata() {}

  /// @notice Receives a message from L1 and saves the proposal metadata.
  /// @param payload The payload that was sent to in the delivery request.
  function receiveWormholeMessages(bytes memory payload, bytes[] memory, bytes32, uint16, bytes32)
    public
    override
    onlyRelayer
  {
    (uint256 proposalId, uint256 voteStart, uint256 voteEnd) =
      abi.decode(payload, (uint256, uint256, uint256));

    _addProposal(proposalId, voteStart, voteEnd);
  }
}