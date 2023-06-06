// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {Script, stdJson} from "forge-std/Script.sol";
import {IL1GovernorMetadataBridge} from "src/interfaces/IL1GovernorMetadataBridge.sol";
import {IGovernor} from "openzeppelin/governance/Governor.sol";
import {FakeERC20} from "src/FakeERC20.sol";
import {Constants} from "test/Constants.sol";

contract SendProposalToL2 is Script, Constants {
  using stdJson for string;

  function run() public {
    string memory governorMetadataDeploy =
      "broadcast/multi/DeployGovernorMetadata.s.sol-latest/run.json";
    string memory json = vm.readFile(governorMetadataDeploy);

    address governorErc20 = json.readAddress(".deployments[1].transactions[0].contractAddress");
    address governorMock = json.readAddress(".deployments[1].transactions[1].contractAddress");
    address l1GovernorMetadataBridge =
      json.readAddress(".deployments[1].transactions[2].contractAddress");

    setFallbackToDefaultRpcUrls(false);
    vm.createSelectFork(getChain("avalanche_fuji").rpcUrl);
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

    // Bridge proposal from the L1 to the L2
    vm.broadcast();
    IL1GovernorMetadataBridge(l1GovernorMetadataBridge).bridge(proposalId);
  }
}
