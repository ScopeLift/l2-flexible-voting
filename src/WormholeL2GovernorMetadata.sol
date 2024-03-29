// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {WormholeReceiver} from "src/WormholeReceiver.sol";
import {WormholeBase} from "src/WormholeBase.sol";
import {L2GovernorMetadata} from "src/L2GovernorMetadata.sol";

/// @notice Use Wormhole to receive L1 proposal metadata.
contract WormholeL2GovernorMetadata is L2GovernorMetadata, WormholeReceiver {
  /// @param _relayer The address of the WormholeL2GovernorMetadata contract.
  /// @param _owner The address that will become the contract owner.
  constructor(address _relayer, address _owner, address _l1BlockAddress, uint32 _castWindow)
    WormholeBase(_relayer, _owner)
    WormholeReceiver()
    L2GovernorMetadata(_l1BlockAddress, _castWindow)
  {}

  /// @notice Receives a message from L1 and saves the proposal metadata.
  /// @param payload The payload that was sent to in the delivery request.
  function receiveWormholeMessages(
    bytes calldata payload,
    bytes[] memory,
    bytes32 sourceAddress,
    uint16 sourceChain,
    bytes32 deliveryHash
  )
    public
    override
    onlyRelayer
    isRegisteredSender(sourceChain, sourceAddress)
    replayProtect(deliveryHash)
  {
    (uint256 proposalId, uint256 voteStart, uint256 voteEnd, bool isCanceled) =
      abi.decode(payload, (uint256, uint256, uint256, bool));

    _addProposal(proposalId, voteStart, voteEnd, isCanceled);
  }
}
