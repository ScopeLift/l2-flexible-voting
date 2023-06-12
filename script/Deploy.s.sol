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
import {Script, stdJson} from "forge-std/Script.sol";
import {L1ERC20Bridge} from "src/L1ERC20Bridge.sol";
import {L2ERC20} from "src/L2ERC20.sol";
import {console2} from "forge-std/console2.sol";
import {IERC20Receive} from "src/interfaces/IERC20Mint.sol";

contract Deploy is Script {
  using stdJson for string;

  function run() public {
    // Deploy the bridge
    // then deploy the erc20Votes token
    //
    // Avalanche is mimicking the L1
    address core =  0x7bbcE28e64B3F8b84d876Ab298393c38ad7aac4C;
    string memory file = "broadcast/DeployFakeERC20.s.sol/43113/run-latest.json";
    string memory json = vm.readFile(file);
    address deployedL1Token = json.readAddress(".transactions[0].contractAddress");



    // Wormhole id for mumbai
    uint16 targetChain = 5;

    setFallbackToDefaultRpcUrls(false);


    vm.createSelectFork(getChain("polygon_mumbai").rpcUrl);

    vm.broadcast();
    L2ERC20 l2Token = new L2ERC20("Scopeapotomus", "SCOPE", core);

    vm.createSelectFork(getChain("avalanche_fuji").rpcUrl);

    vm.broadcast();
    L1ERC20Bridge bridge = new L1ERC20Bridge(deployedL1Token, core);
    bridge.initialize(address(l2Token));
  }
}
