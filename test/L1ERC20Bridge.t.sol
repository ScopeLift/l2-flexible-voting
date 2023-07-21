// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IGovernor} from "openzeppelin/governance/Governor.sol";

import {IERC20Mint} from "src/interfaces/IERC20Mint.sol";
import {FakeERC20} from "src/FakeERC20.sol";
import {L1ERC20Bridge} from "src/L1ERC20Bridge.sol";
import {Constants} from "test/Constants.sol";
import {GovernorMock} from "test/mock/GovernorMock.sol";

contract L1ERC20BridgeTest is Test, Constants {
  IERC20Mint erc20;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl("avalanche_fuji"));
    erc20 = new FakeERC20("Hello", "WRLD");
  }
}

contract Deposit is L1ERC20BridgeTest {
  function testFork_CorrectlyDepositTokens() public {
    FakeERC20 erc20 = new FakeERC20("Hello", "WRLD");
    IGovernor gov = new GovernorMock("Testington Dao", erc20);
    L1ERC20Bridge bridge =
      new L1ERC20Bridge(address(erc20), wormholeCoreFuji, address(gov), wormholePolygonId);
    bridge.initialize(0xBaA85b5C4c74f53c46872acfF2750f512bcBEC43);
    uint256 cost = bridge.quoteDeliveryCost(wormholeFujiId);

    erc20.approve(address(bridge), 100_000);
    erc20.mint(address(this), 100_000);
    vm.deal(address(this), 100 ether);

    bridge.deposit{value: cost}(address(this), 100_000);
  }
}
