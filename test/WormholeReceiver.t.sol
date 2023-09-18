// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {WormholeBase} from "src/WormholeBase.sol";
import {WormholeReceiver} from "src/WormholeReceiver.sol";
import {Constants} from "test/Constants.sol";
import {WormholeReceiverTestHarness} from "test/harness/WormholeReceiverTestHarness.sol";

contract WormholeReceiverTest is Test, Constants {
  WormholeReceiverTestHarness receiver;

  function setUp() public {
    receiver = new WormholeReceiverTestHarness(L1_CHAIN.wormholeRelayer);
  }
}

contract OnlyRelayer is Test, Constants {
  function testFuzz_SucceedIfCalledByWormholeRelayer(address relayer) public {
    WormholeReceiverTestHarness receiver = new WormholeReceiverTestHarness(relayer);

    vm.prank(relayer);
    receiver.onlyRelayerModifierFunc();
  }

  function testFuzz_RevertIf_NotCalledByWormholeRelayer(address relayer) public {
    vm.assume(relayer != address(this));
    WormholeReceiverTestHarness receiver = new WormholeReceiverTestHarness(relayer);

    vm.expectRevert(WormholeReceiver.OnlyRelayerAllowed.selector);
    receiver.onlyRelayerModifierFunc();
  }
}

contract SetRegisteredSender is WormholeReceiverTest {
  function testFuzz_SuccessfullySetRegisteredSender(uint16 sourceChain, address sender) public {
    bytes32 senderBytes = bytes32(uint256(uint160(address(sender))));
    receiver.setRegisteredSender(sourceChain, senderBytes);

    assertEq(
      receiver.registeredSenders(sourceChain, senderBytes),
      true,
      "Registered sender on source chain is not correct"
    );
  }
}

contract IsRegisteredSender is WormholeReceiverTest {
  function testFuzz_SuccessfullyCallWithRegisteredSender(uint16 sourceChain, address sender) public {
    vm.assume(sender != address(0));
    bytes32 senderBytes = bytes32(uint256(uint160(address(sender))));
    receiver.setRegisteredSender(sourceChain, senderBytes);
    receiver.isRegisteredSenderModifierFunc(sourceChain, senderBytes);
  }

  function testFuzz_RevertIf_NotCalledByRegisteredSender(
    uint16 sourceChain,
    address sender,
    address caller
  ) public {
    bytes32 senderBytes = bytes32(uint256(uint160(address(sender))));

    vm.prank(caller);
    vm.expectRevert(
      abi.encodeWithSelector(WormholeReceiver.UnregisteredSender.selector, senderBytes)
    );
    receiver.isRegisteredSenderModifierFunc(sourceChain, senderBytes);
  }
}

contract ReplayProtect is WormholeReceiverTest {
  function testFuzz_RevertIf_SameDeliveryHashIsUsedTwice(bytes32 deliveryHash) public {
    receiver.exposed_replayProtect(deliveryHash);

    vm.expectRevert(
      abi.encodeWithSelector(WormholeReceiver.AlreadyProcessed.selector, deliveryHash)
    );
    receiver.exposed_replayProtect(deliveryHash);
  }
}
