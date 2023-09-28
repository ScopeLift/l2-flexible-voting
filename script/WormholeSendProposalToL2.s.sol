// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, stdJson} from "forge-std/Script.sol";
import {IL1GovernorMetadataBridge} from "src/interfaces/IL1GovernorMetadataBridge.sol";
import {IGovernor} from "openzeppelin/governance/Governor.sol";
import {FakeERC20} from "src/FakeERC20.sol";
import {Constants} from "test/Constants.sol";

/// @dev This script will create an L1 and L2 governor metadata contract, and have the L1 contract
/// pass a proposal to the L2 metadata contract.
contract WormholeSendProposalToL2 is Script, Constants {
  using stdJson for string;

  function run() public {
    string memory deployFile = "broadcast/multi/WormholeL2FlexibleVotingDeploy.s.sol-latest/run.json"; // multi deployment
    string memory deployJson = vm.readFile(deployFile);


    address governorMock = deployJson.readAddress(".deployments[0].transactions[1].contractAddress");

    address governorErc20 = deployJson.readAddress(".deployments[0].transactions[2].contractAddress");
    address l1GovernorMetadataBridge =
      deployJson.readAddress(".deployments[0].transactions[3].contractAddress");

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
    metadataBridge.bridgeProposalMetadata{value: cost}(proposalId);
  }
}
