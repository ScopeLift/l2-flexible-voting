// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {FakeERC20} from "src/FakeERC20.sol";
import {IERC20Mint} from "src/interfaces/IERC20Mint.sol";
import {L1ERC20Bridge} from "src/L1ERC20Bridge.sol";
import {L1Contracts} from "test/L1Contracts.sol";
import {IWormholeRelayer, VaaKey} from "wormhole/interfaces/relayer/IWormholeRelayer.sol";

import {console2} from "forge-std/console2.sol";

contract L1ERC20BridgeTest is Test, L1Contracts {
  IERC20Mint erc20;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl("avalanche_fuji"));
    // vm.createSelectFork(vm.rpcUrl("polygon_mumbai"));
	erc20 = new FakeERC20("Hello", "WRLD");
  }
}

contract Deposit is L1ERC20BridgeTest {
  function testFork_CorrectlyDepositTokens() public {
    // console2.logUint(block.number);
    L1ERC20Bridge bridge = new L1ERC20Bridge(address(erc20), wormholeRelayer, 5);
	// bridge.initialize(0x709f84918fc0E2F96F4F67813377e7b27aCB63ee);

	// erc20.approve(address(bridge), 100_000);
	// erc20.mint(address(this), 100_000);
	// console2.logAddress(address(bridge));
	// console2.logAddress(address(erc20));
	// console2.logUint(erc20.balanceOf(address(this)));
	// console2.logUint(address(this).balance);
	vm.deal(address(this), 100 ether);
	// Bridge needs money lol
	// vm.deal(address(bridge), 100 ether);

    (uint256 deliveryCost,) = IWormholeRelayer(wormholeRelayer).quoteEVMDeliveryPrice(5, 0, 500_000);
	bridge.deposit{value: deliveryCost}(address(this), 100_000, address(this), 5);
  }
}
