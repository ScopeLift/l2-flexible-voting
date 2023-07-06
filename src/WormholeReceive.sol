// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {IWormhole} from "wormhole/interfaces/IWormhole.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";

abstract contract WormholeReceive is Ownable {
  /// @notice The core bridge used to verify messages.
  IWormhole immutable CORE_BRIDGE;

  /// @notice The mapping of Wormhole chain id to cross chain contract address.
  mapping(uint16 => bytes32) _applicationContracts;

  /// @notice The mapping of a Wormhole message hash to boolean indicating whether the message was
  /// completed or not.
  mapping(bytes32 => bool) _completedMessages;

  constructor(address _core) {
    CORE_BRIDGE = IWormhole(_core);
  }

  /// @dev Validates an encoded Wormhole VAA is valid.
  /// @param encodedMsg The encoded Wormhole VAA.
  function _validateMessage(bytes memory encodedMsg)
    internal
    returns (IWormhole.VM memory vm, bool valid, string memory reason)
  {
    (vm, valid, reason) = CORE_BRIDGE.parseAndVerifyVM(encodedMsg);
    //1. Check Wormhole Guardian Signatures
    //  If the VM is NOT valid, will return the reason it's not valid
    //  If the VM IS valid, reason will be blank
    require(valid, reason);

    //2. Check if the Emitter Chain contract is registered
    require(
      _applicationContracts[vm.emitterChainId] == vm.emitterAddress, "Invalid Emitter Address!"
    );

    //3. Check that the message hasn't already been processed
    require(!_completedMessages[vm.hash], "Message already processed");
    _completedMessages[vm.hash] = true;
    return (vm, valid, reason);
  }

  function receiveEncodedMsg(bytes memory encodedMsg) public virtual;

  /// @notice Registers a new destination chain contract address.
  /// @param chainId The Wormhole chain id of the destination chain.
  /// @param applicationAddr The address of the destination chain contract.
  function registerApplicationContracts(uint16 chainId, bytes32 applicationAddr) public onlyOwner {
    _applicationContracts[chainId] = applicationAddr;
  }
}
