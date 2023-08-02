// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IGovernor} from "openzeppelin/governance/Governor.sol";
import {WormholeRelayerBasicTest} from "wormhole-solidity-sdk/testing/WormholeRelayerTest.sol";

import {L1ERC20Bridge} from "src/L1ERC20Bridge.sol";
import {FakeERC20} from "src/FakeERC20.sol";
import {L1Block} from "src/L1Block.sol";
import {L2ERC20} from "src/L2ERC20.sol";
import {Constants} from "test/Constants.sol";
import {GovernorMock} from "test/mock/GovernorMock.sol";

contract L2ERC20Test is Constants, WormholeRelayerBasicTest {
  L2ERC20 l2Erc20;
  FakeERC20 fake;
  L1ERC20Bridge bridge;

  constructor() {
    setTestnetForkChains(5, 6);
  }

  function setUpSource() public override {
    L1Block l1Block = new L1Block();
    l2Erc20 = new L2ERC20( "Hello", "WRLD", wormholeCoreMumbai, address(l1Block), wormholePolygonId, wormholeFujiId);
  }

  function setUpTarget() public override {
    fake = new FakeERC20("Hello", "WRLD");
    IGovernor gov = new GovernorMock("Testington Dao", fake);
    bridge = new L1ERC20Bridge(address(fake), wormholeCoreFuji, address(gov), wormholeFujiId, wormholePolygonId);
  }
}

contract Constructor is L2ERC20Test {
  function testFuzz_CorrectlySetsAllArgs() public {
    L1Block l1Block = new L1Block();
    L2ERC20 erc20 =
    new L2ERC20( "Hello", "WRLD", 0x0CBE91CF822c73C2315FB05100C2F714765d5c20, address(l1Block), wormholePolygonId, wormholeFujiId);

    assertEq(address(l1Block), address(erc20.L1_BLOCK()));
  }
}

contract Initialize is L2ERC20Test {
  function testFork_CorrectlyInitializeL2Token(address bridge) public {
    l2Erc20.initialize(bridge);
    assertEq(l2Erc20.L1_TOKEN_ADDRESS(), bridge, "L1 bridge address is not setup correctly");
    assertEq(l2Erc20.INITIALIZED(), true, "L1 bridged isn't initialized");
  }

  function testFork_InitlializeL2AddressWhenAlreadyInitialized(address bridge) public {
    l2Erc20.initialize(bridge);

    vm.expectRevert(L2ERC20.AlreadyInitialized.selector);
    l2Erc20.initialize(bridge);
  }
}

contract ReceiveWormholeMessages is L2ERC20Test {
  function testFuzzFork_CorrectlyReceiveWormholeMessages(address account, uint224 amount) public {
    vm.assume(account != address(0)); // Cannot be zero address
    l2Erc20.initialize(address(bridge));

    vm.prank(wormholeCoreMumbai);
    l2Erc20.receiveWormholeMessages(
      abi.encode(account, amount), new bytes[](0), bytes32(""), uint16(0), bytes32("")
    );
    uint256 l2Amount = l2Erc20.balanceOf(account);
    assertEq(l2Amount, amount, "Amount after receive is incorrect");
  }
}

contract Clock is L2ERC20Test {
  function testFuzzFork_CorrectlySetClock(uint48 currentBlock) public {
    l2Erc20.initialize(address(bridge));

    vm.roll(currentBlock);
    uint48 l1Block = l2Erc20.clock(); // The test L1 block implementation uses block.number
    assertEq(l1Block, currentBlock, "Block is incorrect");
  }
}

contract CLOCK_MODE is L2ERC20Test {
  function test_CorrectlySetClockMode() public {
    l2Erc20.initialize(address(bridge));
    string memory mode = l2Erc20.CLOCK_MODE(); // The test L1 block implementation uses block.number

    assertEq(mode, "mode=blocknumber&from=eip155:1", "Block is incorrect");
  }

  // TODO add failure case in CLOCK_MODE
}

contract L1Unlock is L2ERC20Test {
  function testFuzzFork_CorrectlyWithdrawToken(address account, uint96 amount) public {
    vm.assume(account != address(0));

    vm.selectFork(targetFork);
    bridge.initialize(address(l2Erc20));
    fake.mint(address(bridge), amount);

    vm.selectFork(sourceFork);
    l2Erc20.initialize(address(bridge));
    vm.recordLogs();
    vm.prank(wormholeCoreMumbai);
    // Create balance
    l2Erc20.receiveWormholeMessages(
      abi.encode(account, amount), new bytes[](0), bytes32(""), uint16(0), bytes32("")
    );

    uint256 cost = l2Erc20.quoteDeliveryCost(wormholeFujiId);
    vm.deal(account, 1 ether);
    vm.prank(account);
    l2Erc20.l1Unlock{value: cost}(account, amount);

    performDelivery();

    vm.selectFork(targetFork);

    uint256 l1Balance = fake.balanceOf(account);
    assertEq(l1Balance, amount, "L1 balance is incorrect");
  }
}
