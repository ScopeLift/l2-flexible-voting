// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {Script, stdJson} from "forge-std/Script.sol";
import {IERC20Receive} from "src/interfaces/IERC20Mint.sol";
import {Constants} from "test/Constants.sol";

/// @dev This script will register the chain and address of the L1 bridge on the L2 token.
contract RegisterL1Bridge is Script, Constants {
  using stdJson for string;

  function run() public {
    // Get address for the L1 bridge and the L2 ERC20
    string memory file = "broadcast/multi/Deploy.s.sol-latest/run.json";
    string memory json = vm.readFile(file);

    address l2ERC20 = json.readAddress(".deployments[0].transactions[0].contractAddress");
    address l1Bridge = json.readAddress(".deployments[1].transactions[0].contractAddress");
    setFallbackToDefaultRpcUrls(false);

    vm.createSelectFork(getChain("polygon_mumbai").rpcUrl);

    // Register the L1 bridge on the L2 token
    vm.broadcast();
    IERC20Receive(l2ERC20).registerApplicationContracts(
      wormholeFujiId, bytes32(uint256(uint160(l1Bridge)))
    );
  }
}
