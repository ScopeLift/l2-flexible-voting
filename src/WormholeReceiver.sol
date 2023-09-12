// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {Ownable} from "openzeppelin/access/Ownable.sol";

import {WormholeBase} from "src/WormholeBase.sol";

abstract contract WormholeReceiver is Ownable, WormholeBase {
  /// @dev Function called with an address that isn't a relayer.
  error OnlyRelayerAllowed();

  /// @notice The function the wormhole relayer calls when the DeliveryProvider competes a delivery.
  /// @param payload The payload that was sent to in the delivery request.
  /// @param additionalVaas The additional VAAs that requested to be relayed.
  /// @param sourceAddress Address that requested this delivery.
  /// @param sourceChain Chain that the delivery was requested from.
  /// @param deliveryHash Unique identifier of this delivery request.
  function receiveWormholeMessages(
    bytes memory payload,
    bytes[] memory additionalVaas,
    bytes32 sourceAddress,
    uint16 sourceChain,
    bytes32 deliveryHash
  ) public virtual;

  modifier onlyRelayer() {
    if (msg.sender != address(WORMHOLE_RELAYER)) revert OnlyRelayerAllowed();
    _;
  }
}
