// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {IWormholeRelayer} from "wormhole/interfaces/relayer/IWormholeRelayer.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";

abstract contract WormholeReceiver is Ownable {
  /// @notice The wormhole relayer used to trustlessly send messages.
  IWormholeRelayer private immutable WORMHOLE_RELAYER;

  /// @dev Function called with an address that isn't a relayer.
  error OnlyRelayerAllowed();

  /// @param _relayer The address of the Wormhole relayer contract.
  constructor(address _relayer) {
    WORMHOLE_RELAYER = IWormholeRelayer(_relayer);
  }

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
    if(msg.sender != address(WORMHOLE_RELAYER)) {
			revert OnlyRelayerAllowed();
	}
    _;
  }
}
