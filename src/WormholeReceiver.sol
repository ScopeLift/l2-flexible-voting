// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "openzeppelin/access/Ownable.sol";

import {WormholeBase} from "src/WormholeBase.sol";

abstract contract WormholeReceiver is Ownable, WormholeBase {
  /// @dev Function called with an address that isn't a relayer.
  error OnlyRelayerAllowed();

  /// @dev Function was called with an unregistered sender address.
  error UnregisteredSender(bytes32 wormholeAddress);

  /// @dev Message was already delivered by Wormhole.
  error AlreadyProcessed(bytes32 deliveryHash);

  /// @dev A mapping of Wormhole chain ID to a mapping of wormhole serialized sender address to
  /// existence boolean.
  mapping(uint16 => mapping(bytes32 => bool)) public registeredSenders;

  /// @dev A mapping of message hash to a boolean indicating delivery.
  mapping(bytes32 => bool) public seenDeliveryVaaHashes;

  event RegisteredSenderSet(
    address indexed owner, uint16 indexed sourceChain, bytes32 indexed sourceAddress
  );

  constructor(address owner) Ownable() {
    transferOwnership(owner);
  }

  /// @notice The function the wormhole relayer calls when the DeliveryProvider competes a delivery.
  /// @dev Implementation should emit `WormholeMessageReceived`.
  /// @param payload The payload that was sent to in the delivery request.
  /// @param additionalVaas The additional VAAs that requested to be relayed.
  /// @param sourceAddress Address that requested this delivery.
  /// @param sourceChain Chain that the delivery was requested from.
  /// @param deliveryHash Unique identifier of this delivery request.
  function receiveWormholeMessages(
    bytes calldata payload,
    bytes[] memory additionalVaas,
    bytes32 sourceAddress,
    uint16 sourceChain,
    bytes32 deliveryHash
  ) public virtual;

  /// @dev Set a registered sender for a given chain.
  /// @param sourceChain The Wormhole ID of the source chain to set the registered sender.
  /// @param sourceAddress The source address for receiving a wormhole message.
  function setRegisteredSender(uint16 sourceChain, bytes32 sourceAddress) public onlyOwner {
    registeredSenders[sourceChain][sourceAddress] = true;
    emit RegisteredSenderSet(msg.sender, sourceChain, sourceAddress);
  }

  /// @dev Revert when the msg.sender is not the wormhole relayer.
  modifier onlyRelayer() {
    if (msg.sender != address(WORMHOLE_RELAYER)) revert OnlyRelayerAllowed();
    _;
  }

  /// @dev Revert when a call is made by an unregistered address.
  modifier isRegisteredSender(uint16 sourceChain, bytes32 sourceAddress) {
    bool isRegistered = registeredSenders[sourceChain][sourceAddress];
    if (!isRegistered || sourceAddress == bytes32(uint256(uint160(address(0))))) {
      revert UnregisteredSender(sourceAddress);
    }
    _;
  }

  modifier replayProtect(bytes32 deliveryHash) {
    if (seenDeliveryVaaHashes[deliveryHash]) revert AlreadyProcessed(deliveryHash);
    seenDeliveryVaaHashes[deliveryHash] = true;
    _;
  }
}
