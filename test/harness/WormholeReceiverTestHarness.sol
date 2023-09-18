// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {WormholeBase} from "src/WormholeBase.sol";
import {WormholeReceiver} from "src/WormholeReceiver.sol";

contract WormholeReceiverTestHarness is WormholeReceiver {
  constructor(address _relayer) WormholeBase(_relayer) {}
  function receiveWormholeMessages(
    bytes memory payload,
    bytes[] memory additionalVaas,
    bytes32 sourceAddress,
    uint16 sourceChain,
    bytes32 deliveryHash
  ) public virtual override {}

  function onlyRelayerModifierFunc() public onlyRelayer {}

  function isRegisteredSenderModifierFunc(uint16 sourceChain, bytes32 senderAddress)
    public
    isRegisteredSender(sourceChain, senderAddress)
  {}

  function exposed_replayProtect(bytes32 deliveryHash) public replayProtect(deliveryHash) {}
}
