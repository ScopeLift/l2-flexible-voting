// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {Script, stdJson} from "forge-std/Script.sol";
import {Constants} from "test/Constants.sol";
import {WormholeL1ERC20Bridge} from "src/WormholeL1ERC20Bridge.sol";
import {WormholeL2GovernorMetadata} from "src/WormholeL2GovernorMetadata.sol";
import {WormholeL2ERC20} from "src/WormholeL2ERC20.sol";

// @dev Register valid cross chain senders for all of the contracts it is required.
contract RegisterSendingAddresses is Script, Constants {
  using stdJson for string;

  function run() public {
    string memory bridgeDeployFile = "broadcast/multi/Deploy.s.sol-latest/run.json";
    string memory bridgeDeployJson = vm.readFile(bridgeDeployFile);

    // Get L2 token address
    address l2TokenAddr =
      bridgeDeployJson.readAddress(".deployments[0].transactions[0].contractAddress");
    // Get L1 bridge address
    address l1BridgeAddr =
      bridgeDeployJson.readAddress(".deployments[1].transactions[1].contractAddress");

    string memory governorMetadataDeploymentFile =
      "broadcast/multi/DeployGovernorMetadata.s.sol-latest/run.json";
    string memory governorMetadataDeploymentJson = vm.readFile(governorMetadataDeploymentFile);
    /// Get address of the deployed L2 governor metadata contract
    address l2GovernorMetadataAddr =
      governorMetadataDeploymentJson.readAddress(".deployments[0].transactions[0].contractAddress");
    /// Get address of the deployed L1 metadata bridge
    address l1GovernorMetadataAddr =
      governorMetadataDeploymentJson.readAddress(".deployments[1].transactions[0].contractAddress");

    string memory voteAggregatorFile = "broadcast/DeployVoteAggregator.s.sol/43113/run-latest.json";
    string memory voteAggregatorJson = vm.readFile(voteAggregatorFile);
    // Get deployed vote aggregator address
    address voteAggregatorAddr =
      voteAggregatorJson.readAddress(".deployments[0].transactions[1].contractAddress");

    vm.createSelectFork(L1_CHAIN.rpcUrl);

    WormholeL1ERC20Bridge l1Bridge = WormholeL1ERC20Bridge(l1BridgeAddr);

    // Register L2 token on ERC20 bridge
    vm.broadcast();
    l1Bridge.setRegisteredSender(L2_CHAIN.wormholeChainId, _toWormholeAddress(l2TokenAddr));

    // Register Vote Aggregator on L1ERC20 bridge
    vm.broadcast();
    l1Bridge.setRegisteredSender(L2_CHAIN.wormholeChainId, _toWormholeAddress(voteAggregatorAddr));

    vm.createSelectFork(L2_CHAIN.rpcUrl);
    // Register L1 metadata bridge on L2 Metadata
    vm.broadcast();
    WormholeL2GovernorMetadata(l2GovernorMetadataAddr).setRegisteredSender(
      L1_CHAIN.wormholeChainId, _toWormholeAddress(l1GovernorMetadataAddr)
    );
    // Register L1 ERC20 bridge on L2 token
    vm.broadcast();
    WormholeL2ERC20(l2TokenAddr).setRegisteredSender(
      L2_CHAIN.wormholeChainId, _toWormholeAddress(l1BridgeAddr)
    );
  }

  function _toWormholeAddress(address addr) internal pure returns (bytes32) {
    return bytes32(uint256(uint160(addr)));
  }
}
