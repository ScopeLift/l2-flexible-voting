// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {Script, stdJson} from "forge-std/Script.sol";

import {L2GovernorMetadata} from "src/L2GovernorMetadata.sol";
import {Constants} from "test/Constants.sol";

/// @dev This script will register the chain and address of the L1 metadata contract on the L2
/// governor metadata contract.
contract RegisterL1GovernorMetadataBridge is Script, Constants {
  using stdJson for string;

  function run() public {
    string memory file = "broadcast/multi/DeployGovernorMetadata.s.sol-latest/run.json";
    string memory json = vm.readFile(file);

    address l2GovernorMetadata = json.readAddress(".deployments[0].transactions[0].contractAddress");
    address l1GovernorMetadata = json.readAddress(".deployments[1].transactions[2].contractAddress");
    setFallbackToDefaultRpcUrls(false);

    vm.createSelectFork(getChain("polygon_mumbai").rpcUrl);

    // Register the L1 metadata contract on the L2 governor metadata
    vm.broadcast();
    L2GovernorMetadata(l2GovernorMetadata).registerApplicationContracts(
      wormholeFujiId, bytes32(uint256(uint160(l1GovernorMetadata)))
    );
  }
}
