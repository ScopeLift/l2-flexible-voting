// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {WormholeBase} from "src/WormholeBase.sol";
import {WormholeReceiver} from "src/WormholeReceiver.sol";
import {TestConstants} from "test/Constants.sol";

contract WormholeReceiverTestHarness is WormholeReceiver {
  constructor(address _relayer, address _owner) WormholeBase(_relayer, _owner) {}
  function receiveWormholeMessages(
    bytes calldata payload,
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

contract WormholeReceiverTest is Test, TestConstants {
  WormholeReceiverTestHarness receiver;

  event RegisteredSenderSet(
    address indexed owner, uint16 indexed sourceChain, bytes32 indexed sourceAddress
  );

  function setUp() public {
    receiver = new WormholeReceiverTestHarness(L1_CHAIN.wormholeRelayer, msg.sender);
  }
}

contract OnlyRelayer is Test, TestConstants {
  function testFuzz_SucceedIfCalledByWormholeRelayer(address relayer) public {
    WormholeReceiverTestHarness receiver = new WormholeReceiverTestHarness(relayer, msg.sender);

    vm.prank(relayer);
    receiver.onlyRelayerModifierFunc();
  }

  function testFuzz_RevertIf_NotCalledByWormholeRelayer(address relayer) public {
    vm.assume(relayer != address(this));
    WormholeReceiverTestHarness receiver = new WormholeReceiverTestHarness(relayer, msg.sender);

    vm.expectRevert(WormholeReceiver.OnlyRelayerAllowed.selector);
    receiver.onlyRelayerModifierFunc();
  }
}

contract SetRegisteredSender is WormholeReceiverTest {
  function testFuzz_SuccessfullySetRegisteredSender(uint16 sourceChain, address sender) public {
    bytes32 senderBytes = bytes32(uint256(uint160(address(sender))));
    assertEq(receiver.owner(), msg.sender, "Owner is incorrect");

    vm.expectEmit();
    emit RegisteredSenderSet(receiver.owner(), sourceChain, senderBytes);
    vm.prank(receiver.owner());
    receiver.setRegisteredSender(sourceChain, senderBytes);

    assertEq(
      receiver.registeredSenders(sourceChain, senderBytes),
      true,
      "Registered sender on source chain is not correct"
    );
  }

  function testFuzz_RevertIf_OwnerIsNotTheCaller(uint16 sourceChain, address sender, address caller)
    public
  {
    vm.assume(caller != receiver.owner());
    bytes32 senderBytes = bytes32(uint256(uint160(address(sender))));

    vm.expectRevert(bytes("Ownable: caller is not the owner"));
    vm.prank(caller);
    receiver.setRegisteredSender(sourceChain, senderBytes);
  }
}

contract IsRegisteredSender is WormholeReceiverTest {
  function testFuzz_SuccessfullyCallWithRegisteredSender(uint16 sourceChain, address sender) public {
    vm.assume(sender != address(0));
    bytes32 senderBytes = bytes32(uint256(uint160(address(sender))));
    assertEq(receiver.owner(), msg.sender, "Owner is incorrect");

    vm.expectEmit();
    emit RegisteredSenderSet(receiver.owner(), sourceChain, senderBytes);
    vm.prank(receiver.owner());
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
