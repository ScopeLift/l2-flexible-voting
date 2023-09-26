// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IGovernor} from "openzeppelin/governance/Governor.sol";
import {WormholeRelayerBasicTest} from "wormhole-solidity-sdk/testing/WormholeRelayerTest.sol";

import {WormholeL1ERC20Bridge} from "src/WormholeL1ERC20Bridge.sol";
import {FakeERC20} from "src/FakeERC20.sol";
import {L1Block} from "src/L1Block.sol";
import {WormholeL2ERC20} from "src/WormholeL2ERC20.sol";
import {Constants} from "test/Constants.sol";
import {GovernorMock} from "test/mock/GovernorMock.sol";
import {WormholeReceiver} from "src/WormholeReceiver.sol";

contract L2ERC20Test is Constants, WormholeRelayerBasicTest {
  WormholeL2ERC20 l2Erc20;
  FakeERC20 l1Erc20;
  WormholeL1ERC20Bridge l1Erc20Bridge;

  constructor() {
    setForkChains(TESTNET, L2_CHAIN.wormholeChainId, L1_CHAIN.wormholeChainId);
  }

  function setUpSource() public override {
    L1Block l1Block = new L1Block();
    l2Erc20 =
    new WormholeL2ERC20( "Hello", "WRLD", L2_CHAIN.wormholeRelayer, address(l1Block), L2_CHAIN.wormholeChainId, L1_CHAIN.wormholeChainId, msg.sender);

    vm.prank(l2Erc20.owner());
    l2Erc20.setRegisteredSender(L1_CHAIN.wormholeChainId, MOCK_WORMHOLE_SERIALIZED_ADDRESS);
  }

  function setUpTarget() public override {
    l1Erc20 = new FakeERC20("Hello", "WRLD");
    IGovernor gov = new GovernorMock("Testington Dao", l1Erc20);
    l1Erc20Bridge =
    new WormholeL1ERC20Bridge(address(l1Erc20), L1_CHAIN.wormholeRelayer, address(gov), L1_CHAIN.wormholeChainId, L2_CHAIN.wormholeChainId, msg.sender);

    vm.prank(l1Erc20Bridge.owner());
    l1Erc20Bridge.setRegisteredSender(
      L2_CHAIN.wormholeChainId, bytes32(uint256(uint160(address(l2Erc20))))
    );
  }
}

contract Constructor is L2ERC20Test {
  function testFuzz_CorrectlySetsAllArgs() public {
    L1Block l1Block = new L1Block();
    WormholeL2ERC20 erc20 =
    new WormholeL2ERC20( "Hello", "WRLD", 0x0CBE91CF822c73C2315FB05100C2F714765d5c20, address(l1Block), L2_CHAIN.wormholeChainId, L1_CHAIN.wormholeChainId, msg.sender);

    assertEq(address(l1Block), address(erc20.L1_BLOCK()));
  }
}

contract Initialize is L2ERC20Test {
  function testFork_CorrectlyInitializeL2Token(address l1Erc20Bridge) public {
    l2Erc20.initialize(l1Erc20Bridge);
    assertEq(l2Erc20.L1_TOKEN_ADDRESS(), l1Erc20Bridge, "L1 bridge address is not setup correctly");
    assertEq(l2Erc20.INITIALIZED(), true, "L1 bridged isn't initialized");
  }

  function testFork_RevertWhen_AlreadyInitializedWithBridgeAddress(address l1Erc20Bridge) public {
    l2Erc20.initialize(l1Erc20Bridge);

    vm.expectRevert(WormholeL2ERC20.AlreadyInitialized.selector);
    l2Erc20.initialize(l1Erc20Bridge);
  }
}

contract ReceiveWormholeMessages is L2ERC20Test {
  function testForkFuzz_CorrectlyReceiveWormholeMessages(address account, uint224 l1Amount) public {
    vm.assume(account != address(0)); // Cannot be zero address
    l2Erc20.initialize(address(l1Erc20Bridge));

    vm.prank(L2_CHAIN.wormholeRelayer);
    l2Erc20.receiveWormholeMessages(
      abi.encode(account, l1Amount),
      new bytes[](0),
      MOCK_WORMHOLE_SERIALIZED_ADDRESS,
      L1_CHAIN.wormholeChainId,
      bytes32("")
    );
    uint256 l2Amount = l2Erc20.balanceOf(account);
    assertEq(l2Amount, l1Amount, "Amount after receive is incorrect");
  }

  function testFuzz_RevertIf_NotCalledByRelayer(address account, uint256 amount, address caller)
    public
  {
    bytes memory payload = abi.encode(account, amount);
    vm.prank(caller);
    vm.expectRevert(WormholeReceiver.OnlyRelayerAllowed.selector);
    l2Erc20.receiveWormholeMessages(
      payload,
      new bytes[](0),
      MOCK_WORMHOLE_SERIALIZED_ADDRESS,
      L1_CHAIN.wormholeChainId,
      bytes32("")
    );
  }

  function testFuzz_RevertIf_NotCalledByRegisteredSender(
    address account,
    uint256 amount,
    bytes32 caller
  ) public {
    vm.assume(caller != MOCK_WORMHOLE_SERIALIZED_ADDRESS);

    bytes memory payload = abi.encode(account, amount);
    vm.prank(L2_CHAIN.wormholeRelayer);
    vm.assume(caller != MOCK_WORMHOLE_SERIALIZED_ADDRESS);
    vm.expectRevert(abi.encodeWithSelector(WormholeReceiver.UnregisteredSender.selector, caller));
    l2Erc20.receiveWormholeMessages(
      payload, new bytes[](0), caller, L1_CHAIN.wormholeChainId, bytes32("")
    );
  }
}

contract Clock is L2ERC20Test {
  function testForkFuzz_CorrectlySetClock(uint48 currentBlock) public {
    l2Erc20.initialize(address(l1Erc20Bridge));

    vm.roll(currentBlock);
    uint48 l1Block = l2Erc20.clock(); // The test L1 block implementation uses block.number
    assertEq(l1Block, currentBlock, "L2 clock is incorrect");
  }
}

contract CLOCK_MODE is L2ERC20Test {
  function test_CorrectlySetClockMode() public {
    l2Erc20.initialize(address(l1Erc20Bridge));
    string memory mode = l2Erc20.CLOCK_MODE();

    assertEq(mode, "mode=blocknumber&from=eip155:1", "Clock mode is incorrect");
  }
}

contract L1Unlock is L2ERC20Test {
  function testForkFuzz_CorrectlyWithdrawToken(address account, uint96 amount) public {
    vm.assume(account != address(0));

    vm.selectFork(targetFork);
    l1Erc20Bridge.initialize(address(l2Erc20));
    l1Erc20.mint(address(l1Erc20Bridge), amount);

    vm.selectFork(sourceFork);
    l2Erc20.initialize(address(l1Erc20Bridge));
    vm.recordLogs();
    vm.prank(L2_CHAIN.wormholeRelayer);
    l2Erc20.receiveWormholeMessages(
      abi.encode(account, amount),
      new bytes[](0),
      MOCK_WORMHOLE_SERIALIZED_ADDRESS,
      L1_CHAIN.wormholeChainId,
      bytes32("")
    );

    uint256 cost = l2Erc20.quoteDeliveryCost(L1_CHAIN.wormholeChainId);
    vm.deal(account, 1 ether);
    vm.prank(account);
    l2Erc20.l1Unlock{value: cost}(account, amount);

    performDelivery();

    vm.selectFork(targetFork);

    uint256 l1Balance = l1Erc20.balanceOf(account);
    assertEq(l1Balance, amount, "L1 balance is incorrect");
  }
}
