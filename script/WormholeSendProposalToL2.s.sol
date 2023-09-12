// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {Script, stdJson} from "forge-std/Script.sol";
import {IL1GovernorMetadataBridge} from "src/interfaces/IL1GovernorMetadataBridge.sol";
import {IGovernor} from "openzeppelin/governance/Governor.sol";
import {FakeERC20} from "src/FakeERC20.sol";
import {Constants} from "test/Constants.sol";

/// @dev This script will create an L1 and L2 governor metadata contract, and have the L1 contract
/// pass a proposal to the L2 metadata contract.
contract SendProposalToL2 is Script, Constants {
  using stdJson for string;

  function run() public {
    string memory governorMetadataDeploy =
      "broadcast/multi/DeployGovernorMetadata.s.sol-latest/run.json";
    string memory json = vm.readFile(governorMetadataDeploy);
    address governorMock = json.readAddress(".deployments[1].transactions[0].contractAddress");

    string memory tokenFile = "broadcast/DeployFakeERC20.s.sol/43113/run-latest.json";
    string memory tokenJson = vm.readFile(tokenFile);
    address governorErc20 = tokenJson.readAddress(".transactions[0].contractAddress");
    address l1GovernorMetadataBridge =
      json.readAddress(".deployments[1].transactions[2].contractAddress");

    setFallbackToDefaultRpcUrls(false);
    vm.createSelectFork(L1_CHAIN.rpcUrl);
    bytes memory mintCalldata = abi.encode(FakeERC20.mint.selector, governorMock, 1 ether);

    address[] memory targets = new address[](1);
    bytes[] memory calldatas = new bytes[](1);
    uint256[] memory values = new uint256[](1);

    targets[0] = governorErc20;
    calldatas[0] = mintCalldata;
    values[0] = 0;

    // Create L2 Proposal
    vm.broadcast();
    uint256 proposalId = IGovernor(governorMock).propose(
      targets,
      values,
      calldatas,
      string.concat("Proposal: To inflate governance token", string(abi.encode(block.number)))
    );

    IL1GovernorMetadataBridge metadataBridge = IL1GovernorMetadataBridge(l1GovernorMetadataBridge);
    uint256 cost = metadataBridge.quoteDeliveryCost(L2_CHAIN.wormholeChainId);

    // Bridge proposal from the L1 to the L2
    vm.broadcast();
    metadataBridge.bridge{value: cost}(proposalId);
  }
}