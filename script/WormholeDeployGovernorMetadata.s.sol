// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, stdJson} from "forge-std/Script.sol";
import {IGovernor} from "openzeppelin/governance/Governor.sol";
import {ERC20Votes} from "openzeppelin/token/ERC20/extensions/ERC20Votes.sol";

import {WormholeL1GovernorMetadataBridge} from "src/WormholeL1GovernorMetadataBridge.sol";
import {WormholeL2GovernorMetadata} from "src/WormholeL2GovernorMetadata.sol";
import {FakeERC20} from "src/FakeERC20.sol";
import {GovernorMock} from "test/mock/GovernorMock.sol";
import {Constants} from "test/Constants.sol";

/// @notice Deploy the L2 GovernorMetadata contract along with the L1 GovernorMetadata bridge.
contract DeployGovernorMetadata is Script, Constants {
  using stdJson for string;

  function run() public {
    Constants.ChainConfig memory L1_CHAIN = chainInfos[L1_CHAIN_ID];
    Constants.ChainConfig memory L2_CHAIN = chainInfos[L2_CHAIN_ID];

    setFallbackToDefaultRpcUrls(false);

    string memory file = "broadcast/DeployFakeERC20.s.sol/43113/run-latest.json";
    string memory json = vm.readFile(file);
    address deployedL1Token = json.readAddress(".transactions[0].contractAddress");

    vm.createSelectFork(L2_CHAIN.rpcUrl);

    // Deploy the L2 metadata contract
    vm.broadcast();
    WormholeL2GovernorMetadata l2GovernorMetadata =
      new WormholeL2GovernorMetadata(L2_CHAIN.wormholeRelayer, msg.sender);

    vm.createSelectFork(L1_CHAIN.rpcUrl);

    // Create L1 Governor with corresponding ERC20Votes
    vm.broadcast();
    IGovernor gov = new GovernorMock("Testington Dao", ERC20Votes(deployedL1Token));

    // Create L1 Governor metadata bridge
    vm.broadcast();
    WormholeL1GovernorMetadataBridge bridge =
    new WormholeL1GovernorMetadataBridge(address(gov), L1_CHAIN.wormholeRelayer, L1_CHAIN.wormholeChainId, L2_CHAIN.wormholeChainId);

    // Add L2 metadata contract to L1 Governor metadata bridge
    vm.broadcast();
    bridge.initialize(address(l2GovernorMetadata));
  }
}
