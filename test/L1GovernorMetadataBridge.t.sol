// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Governor, IGovernor} from "openzeppelin/governance/Governor.sol";
import {ERC20Votes} from "openzeppelin/token/ERC20/extensions/ERC20Votes.sol";

import {L1GovernorMetadataBridge} from "src/L1GovernorMetadataBridge.sol";
import {FakeERC20} from "src/FakeERC20.sol";
import {Constants} from "test/Constants.sol";
import {GovernorMock} from "test/mock/GovernorMock.sol";

contract L1GovernorMetadataBridgeTest is Test, Constants {
  function setUp() public {
    vm.createSelectFork(vm.rpcUrl("avalanche_fuji"));
  }
}

contract Bridge is L1GovernorMetadataBridgeTest {
  function testFork_CorrectlyBridgeMetadata() public {
    ERC20Votes erc20 = new FakeERC20("GovExample", "GOV");
    IGovernor gov = new GovernorMock("Testington Dao", erc20);
    L1GovernorMetadataBridge bridge = new L1GovernorMetadataBridge(address(gov), wormholeCoreFuji);
    bridge.initialize(0xBaA85b5C4c74f53c46872acfF2750f512bcBEC43);

    bytes memory mintCalldata = abi.encode(FakeERC20.mint.selector, address(gov), 1 ether);

    address[] memory targets = new address[](1);
    bytes[] memory calldatas = new bytes[](1);
    uint256[] memory values = new uint256[](1);

    targets[0] = address(erc20);
    calldatas[0] = mintCalldata;
    values[0] = 0;

    // Create proposal
    uint256 proposalId =
      gov.propose(targets, values, calldatas, "Proposal: To inflate governance token");

    uint256 sequence = bridge.bridge(proposalId);

    assertEq(sequence, 0);
  }
}
