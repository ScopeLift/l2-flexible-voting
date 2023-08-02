// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {Script, stdJson} from "forge-std/Script.sol";
import {IGovernor} from "openzeppelin/governance/Governor.sol";
import {ERC20Votes} from "openzeppelin/token/ERC20/extensions/ERC20Votes.sol";

import {L1GovernorMetadataBridge} from "src/L1GovernorMetadataBridge.sol";
import {L2GovernorMetadata} from "src/L2GovernorMetadata.sol";
import {FakeERC20} from "src/FakeERC20.sol";
import {GovernorMock} from "test/mock/GovernorMock.sol";
import {Constants} from "test/Constants.sol";

/// @notice Deploy the L2 GovernorMetadata contract along with the L1 GovernorMetadata bridge.
contract DeployGovernorMetadata is Script, Constants {
  using stdJson for string;

  function run() public {
    setFallbackToDefaultRpcUrls(false);

    string memory file = "broadcast/DeployFakeERC20.s.sol/43113/run-latest.json";
    string memory json = vm.readFile(file);
    address deployedL1Token = json.readAddress(".transactions[0].contractAddress");

    vm.createSelectFork(getChain("polygon_mumbai").rpcUrl);

    // Deploy the L2 metadata contract
    vm.broadcast();
    L2GovernorMetadata l2GovernorMetadata = new L2GovernorMetadata(wormholeCoreMumbai);

    vm.createSelectFork(getChain("avalanche_fuji").rpcUrl);

    // Create L1 Governor with corresponding ERC20Votes
    vm.broadcast();
    IGovernor gov = new GovernorMock("Testington Dao", ERC20Votes(deployedL1Token));

    // Create L1 Governor metadata bridge
    vm.broadcast();
    L1GovernorMetadataBridge bridge =
      new L1GovernorMetadataBridge(address(gov), wormholeCoreFuji, wormholeFujiId, wormholePolygonId);

    // Add L2 metadata contract to L1 Governor metadata bridge
    vm.broadcast();
    bridge.initialize(address(l2GovernorMetadata));
  }
}
