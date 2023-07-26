// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {Script, stdJson} from "forge-std/Script.sol";

import {Constants} from "test/Constants.sol";
import {L2VoteAggregator} from "src/L2VoteAggregator.sol";
import {L1VotePool} from "src/L1VotePool.sol";
import {L1Block} from "src/L1Block.sol";

/// @dev Reads the L2 governor metadata contract address and deploys an L2 vote aggregator contract
/// to test collecting votes on L2.
contract DeployVoteAggregator is Script, Constants {
  using stdJson for string;

  function run() public {
    /// Get address of the deployed L2 token
    string memory erc20BridgeFile = "broadcast/multi/Deploy.s.sol-latest/run.json";
    string memory erc20Json = vm.readFile(erc20BridgeFile);
    address deployedL2Token =
      erc20Json.readAddress(".deployments[0].transactions[0].contractAddress");

    /// Get address of the deployed L2 governor metadata contract
    string memory l2GovernorMetadataFile =
      "broadcast/multi/DeployGovernorMetadata.s.sol-latest/run.json";
    string memory l2GovernorMetadataJson = vm.readFile(l2GovernorMetadataFile);
    address l2GovernorMetadata =
      l2GovernorMetadataJson.readAddress(".deployments[0].transactions[0].contractAddress");

    setFallbackToDefaultRpcUrls(false);

    vm.createSelectFork(getChain("polygon_mumbai").rpcUrl);

    // Create L1 block contract
    vm.broadcast();
    L1Block l1Block = new L1Block();

    // Deploy the L2 vote aggregator
    vm.broadcast();
    new L2VoteAggregator(deployedL2Token, wormholeCoreMumbai, l2GovernorMetadata, address(l1Block));
  }
}
