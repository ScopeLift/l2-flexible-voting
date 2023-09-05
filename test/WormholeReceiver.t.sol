// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {WormholeBase} from "src/WormholeBase.sol";
import {WormholeReceiver} from "src/WormholeReceiver.sol";
import {Constants} from "test/Constants.sol";

contract WormholeReceiverTestHarness is WormholeReceiver {
  constructor(address _relayer) WormholeBase(_relayer) {}
  function receiveWormholeMessages(
    bytes memory payload,
    bytes[] memory additionalVaas,
    bytes32 sourceAddress,
    uint16 sourceChain,
    bytes32 deliveryHash
  ) public virtual override {}

  function modifierTest() public onlyRelayer {}
}

contract OnlyRelayerTest is Test, Constants {
  function testFuzz_SucceedsIfCalledByWormholeRelayer(address relayer) public {
    WormholeReceiverTestHarness receiver = new WormholeReceiverTestHarness(relayer);

    vm.prank(relayer);
    receiver.modifierTest();
  }

  function testFuzz_RevertIf_NotCalledByWormholeRelayer(address relayer) public {
    vm.assume(relayer != address(this));
    WormholeReceiverTestHarness receiver = new WormholeReceiverTestHarness(relayer);

    vm.expectRevert(WormholeReceiver.OnlyRelayerAllowed.selector);
    receiver.modifierTest();
  }
}
