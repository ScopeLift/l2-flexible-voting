// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {Script, stdJson} from "forge-std/Script.sol";
import {L1ERC20Bridge} from "src/L1ERC20Bridge.sol";
import {L2ERC20} from "src/L2ERC20.sol";
import {Constants} from "test/Constants.sol";

/// @notice Deploy L1 bridge and corresponding token to be minted on L2
contract Deploy is Script, Constants {
  using stdJson for string;

  function run() public {
    // Get the contract address for the L1 ERC20Votes token
    string memory file = "broadcast/DeployFakeERC20.s.sol/43113/run-latest.json";
    string memory json = vm.readFile(file);
    address deployedL1Token = json.readAddress(".transactions[0].contractAddress");

    setFallbackToDefaultRpcUrls(false);

    vm.createSelectFork(getChain("polygon_mumbai").rpcUrl);

    // Create L2 ERC20Votes token
    vm.broadcast();
    L2ERC20 l2Token = new L2ERC20("Scopeapotomus", "SCOPE", wormholeCoreMumbai);

    vm.createSelectFork(getChain("avalanche_fuji").rpcUrl);

    // Create L1 bridge that mints the L2 token
    vm.broadcast();
    L1ERC20Bridge bridge = new L1ERC20Bridge(deployedL1Token, wormholeCoreFuji);

    // Tell the bridge its corresponding L2 token
    vm.broadcast();
    bridge.initialize(address(l2Token));
  }
}
