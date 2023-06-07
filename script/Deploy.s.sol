// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

// Write multi network deploy script
// Take a look at the contracts-periphery
// Has a multi network deploy script
//
// Next steps after deploy
//
// Write a script to execute a test transaction, verify this works
// Then cleanup implmentation, validation
// and solving the address problem
// use the initializer pattern, probably the ERC20, then deploy script
// deploy one and then the other, production level
//
// No tests for now, handle mocks in a separate pr or issue

// Pull Ed in early next week, few calls with Ed, second call would
// probably handle L2 flexible voting.
import {Script} from "forge-std/Script.sol";
import {L1ERC20Bridge} from "src/L1ERC20Bridge.sol";
import {L2ERC20} from "src/L2ERC20.sol";

contract Deploy is Script {
  function run() public {
    // Deploy the bridge
    // then deploy the erc20Votes token
    //
    // Avalanche is mimicking the L1
    address deployedL1Token = 0x630567C26340Da0700E6572E0FFa72e10e002B35;
    address relayer = 0xA3cF45939bD6260bcFe3D66bc73d60f19e49a8BB;
    // Wormhole id for mumbai
    uint16 targetChain = 5;

    setFallbackToDefaultRpcUrls(false);

    vm.createSelectFork(getChain("avalanche_fuji").rpcUrl);
	vm.broadcast();
	L2ERC20 l2Token = new L2ERC20("Scopeapotomus", "SCOPE"); 

    vm.createSelectFork(getChain("polygon_mumbai").rpcUrl);

	vm.broadcast();
    L1ERC20Bridge bridge = new L1ERC20Bridge(deployedL1Token, relayer, targetChain);
	bridge.initialize(address(l2Token));
  }
}
