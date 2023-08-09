// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Governor, IGovernor} from "openzeppelin/governance/Governor.sol";
import {ERC20Votes} from "openzeppelin/token/ERC20/extensions/ERC20Votes.sol";
import {WormholeRelayerBasicTest} from "wormhole-solidity-sdk/testing/WormholeRelayerTest.sol";

import {L1GovernorMetadataBridge} from "src/L1GovernorMetadataBridge.sol";
import {FakeERC20} from "src/FakeERC20.sol";
import {L2GovernorMetadata} from "src/L2GovernorMetadata.sol";
import {Constants} from "test/Constants.sol";
import {GovernorMock} from "test/mock/GovernorMock.sol";

contract L1GovernorMetadataBridgeTest is Constants, WormholeRelayerBasicTest {
  FakeERC20 l1Erc20;
  GovernorMock gov;
  L1GovernorMetadataBridge bridge;
  L2GovernorMetadata l2GovernorMetadata;

  constructor() {
    setTestnetForkChains(6, 5);
  }

  function setUpSource() public override {
    ERC20Votes erc20 = new FakeERC20("GovExample", "GOV");
    gov = new GovernorMock("Testington Dao", erc20);
    bridge =
    new L1GovernorMetadataBridge(address(gov), wormholeCoreFuji, wormholeFujiId, wormholePolygonId);
  }

  function setUpTarget() public override {
    l2GovernorMetadata = new L2GovernorMetadata(wormholeCoreMumbai);
  }
}

contract Constructor is Test, Constants {
  function testFork_CorrectlySetAllArgs(address gov) public {
    L1GovernorMetadataBridge bridge =
      new L1GovernorMetadataBridge(gov, wormholeCoreFuji, wormholeFujiId, wormholePolygonId);
    assertEq(address(bridge.GOVERNOR()), gov, "Governor is not set correctly");
  }
}

contract Initialize is L1GovernorMetadataBridgeTest {
  function testFork_CorrectlyInitializeL2GovernorMetadata(address l2GovernorMetadata) public {
    bridge.initialize(address(l2GovernorMetadata));
    assertEq(
      bridge.L2_GOVERNOR_ADDRESS(), l2GovernorMetadata, "L2 governor address is not setup correctly"
    );
    assertEq(bridge.INITIALIZED(), true, "Bridge isn't initialized");
  }

  function testFork_RevertWhen_AlreadyIntializedWithL2GovernorMetadataAddress(address l2GovernorMetadata)
    public
  {
    bridge.initialize(address(l2GovernorMetadata));

    vm.expectRevert(L1GovernorMetadataBridge.AlreadyInitialized.selector);
    bridge.initialize(address(l2GovernorMetadata));
  }
}

contract Bridge is L1GovernorMetadataBridgeTest {
  function testFork_CorrectlyBridgeProposal(uint224 _amount) public {
    bridge.initialize(address(l2GovernorMetadata));
    uint256 cost = bridge.quoteDeliveryCost(wormholeFujiId);
    vm.recordLogs();

    bytes memory proposalCalldata = abi.encode(FakeERC20.mint.selector, address(gov), _amount);

    address[] memory targets = new address[](1);
    bytes[] memory calldatas = new bytes[](1);
    uint256[] memory values = new uint256[](1);

    targets[0] = address(l1Erc20);
    calldatas[0] = proposalCalldata;
    values[0] = 0;

    // Create proposal
    uint256 proposalId =
      gov.propose(targets, values, calldatas, "Proposal: To inflate governance token");

    bridge.bridge{value: cost}(proposalId);
    uint256 l1VoteStart = gov.proposalSnapshot(proposalId);
    uint256 l1VoteEnd = gov.proposalDeadline(proposalId);

    performDelivery();

    vm.selectFork(targetFork);
    L2GovernorMetadata.Proposal memory l2Proposal = l2GovernorMetadata.getProposal(proposalId);
    assertEq(l2Proposal.voteStart, l1VoteStart, "voteStart is incorrect");
    assertEq(l2Proposal.voteEnd, l1VoteEnd, "voteEnd is incorrect");
  }

  function testFork_RevertWhen_ProposalIsMissing(uint256 _proposalId) public {
    bridge.initialize(address(l2GovernorMetadata));
    uint256 cost = bridge.quoteDeliveryCost(wormholeFujiId);
    vm.recordLogs();

    vm.expectRevert(L1GovernorMetadataBridge.InvalidProposalId.selector);
    bridge.bridge{value: cost}(_proposalId);
  }
}
