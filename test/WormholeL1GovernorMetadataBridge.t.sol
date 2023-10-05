// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC20Votes} from "openzeppelin/token/ERC20/extensions/ERC20Votes.sol";
import {WormholeRelayerBasicTest} from "wormhole-solidity-sdk/testing/WormholeRelayerTest.sol";

import {WormholeL1GovernorMetadataBridge} from "src/WormholeL1GovernorMetadataBridge.sol";
import {FakeERC20} from "src/FakeERC20.sol";
import {L2GovernorMetadata} from "src/L2GovernorMetadata.sol";
import {WormholeL2GovernorMetadata} from "src/WormholeL2GovernorMetadata.sol";
import {TestConstants} from "test/Constants.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {GovernorMock} from "test/mock/GovernorMock.sol";

contract L1GovernorMetadataBridgeTest is TestConstants, WormholeRelayerBasicTest {
  FakeERC20 l1Erc20;
  GovernorMock governorMock;
  WormholeL1GovernorMetadataBridge l1GovernorMetadataBridge;
  WormholeL2GovernorMetadata l2GovernorMetadata;

  event ProposalCreated(
    uint256 proposalId,
    address proposer,
    address[] targets,
    uint256[] values,
    string[] signatures,
    bytes[] calldatas,
    uint256 startBlock,
    uint256 endBlock,
    string description
  );
  event ProposalMetadataBridged(
    uint16 indexed targetChain,
    address indexed targetGovernor,
    uint256 indexed proposalId,
    uint256 voteStart,
    uint256 voteEnd,
    bool isCanceled
  );
  event ProposalCanceled(uint256 proposalId);

  constructor() {
    setForkChains(TESTNET, L1_CHAIN.wormholeChainId, L2_CHAIN.wormholeChainId);
  }

  function setUpSource() public override {
    ERC20Votes erc20 = new FakeERC20("GovExample", "GOV");
    governorMock = new GovernorMock("Testington Dao", erc20);
    l1GovernorMetadataBridge =
    new WormholeL1GovernorMetadataBridge(address(governorMock), L1_CHAIN.wormholeRelayer, L1_CHAIN.wormholeChainId, L2_CHAIN.wormholeChainId);
  }

  function setUpTarget() public override {
    l2GovernorMetadata = new WormholeL2GovernorMetadata(L2_CHAIN.wormholeRelayer, msg.sender);
    vm.prank(l2GovernorMetadata.owner());
    l2GovernorMetadata.setRegisteredSender(
      L1_CHAIN.wormholeChainId, bytes32(uint256(uint160(address(l1GovernorMetadataBridge))))
    );
  }
}

contract Constructor is Test, TestConstants {
  function testFork_CorrectlySetAllArgs(address governorMock) public {
    WormholeL1GovernorMetadataBridge l1GovernorMetadataBridge =
    new WormholeL1GovernorMetadataBridge(governorMock, L1_CHAIN.wormholeRelayer, L1_CHAIN.wormholeChainId, L2_CHAIN.wormholeChainId);
    assertEq(
      address(l1GovernorMetadataBridge.GOVERNOR()), governorMock, "Governor is not set correctly"
    );
  }
}

contract Initialize is L1GovernorMetadataBridgeTest {
  function testFork_CorrectlyInitializeL2GovernorMetadata(address l2GovernorMetadata) public {
    l1GovernorMetadataBridge.initialize(address(l2GovernorMetadata));
    assertEq(
      l1GovernorMetadataBridge.L2_GOVERNOR_ADDRESS(),
      l2GovernorMetadata,
      "L2 governor address is not setup correctly"
    );
    assertEq(l1GovernorMetadataBridge.INITIALIZED(), true, "Bridge isn't initialized");
  }

  function testFork_RevertWhen_AlreadyInitializedWithL2GovernorMetadataAddress(
    address l2GovernorMetadata
  ) public {
    l1GovernorMetadataBridge.initialize(address(l2GovernorMetadata));

    vm.expectRevert(WormholeL1GovernorMetadataBridge.AlreadyInitialized.selector);
    l1GovernorMetadataBridge.initialize(address(l2GovernorMetadata));
  }
}

contract BridgeProposalMetadata is L1GovernorMetadataBridgeTest {
  function testFork_CorrectlyBridgeProposal(uint224 _amount) public {
    l1GovernorMetadataBridge.initialize(address(l2GovernorMetadata));
    uint256 cost = l1GovernorMetadataBridge.quoteDeliveryCost(L2_CHAIN.wormholeChainId);
    vm.recordLogs();

    bytes memory proposalCalldata =
      abi.encode(FakeERC20.mint.selector, address(governorMock), _amount);

    address[] memory targets = new address[](1);
    bytes[] memory calldatas = new bytes[](1);
    uint256[] memory values = new uint256[](1);

    targets[0] = address(l1Erc20);
    calldatas[0] = proposalCalldata;
    values[0] = 0;

    // Create proposal
    uint256 proposalId =
      governorMock.propose(targets, values, calldatas, "Proposal: To inflate governance token");

    vm.expectEmit();
    emit ProposalMetadataBridged(
      L2_CHAIN.wormholeChainId,
      address(l2GovernorMetadata),
      proposalId,
      governorMock.proposalSnapshot(proposalId),
      governorMock.proposalDeadline(proposalId),
      false
    );
    l1GovernorMetadataBridge.bridgeProposalMetadata{value: cost}(proposalId);
    uint256 l1VoteStart = governorMock.proposalSnapshot(proposalId);
    uint256 l1VoteEnd = governorMock.proposalDeadline(proposalId);

    vm.expectEmit();
    emit ProposalCreated(
      proposalId,
      address(0),
      new address[](0),
      new uint256[](0),
      new string[](0),
      new bytes[](0),
      l1VoteStart,
      l1VoteEnd,
      string.concat("Mainnet proposal ", Strings.toString(proposalId))
    );
    performDelivery();

    vm.selectFork(targetFork);
    L2GovernorMetadata.Proposal memory l2Proposal = l2GovernorMetadata.getProposal(proposalId);
    assertEq(l2Proposal.voteStart, l1VoteStart, "voteStart is incorrect");
    assertEq(l2Proposal.voteEnd, l1VoteEnd, "voteEnd is incorrect");
    assertEq(l2Proposal.isCanceled, false, "isCanceled is incorrect");
  }

  function testFork_CorrectlyBridgeCanceledProposal(uint224 _amount) public {
    l1GovernorMetadataBridge.initialize(address(l2GovernorMetadata));
    uint256 cost = l1GovernorMetadataBridge.quoteDeliveryCost(L2_CHAIN.wormholeChainId);
    vm.recordLogs();

    bytes memory proposalCalldata =
      abi.encode(FakeERC20.mint.selector, address(governorMock), _amount);

    address[] memory targets = new address[](1);
    bytes[] memory calldatas = new bytes[](1);
    uint256[] memory values = new uint256[](1);

    targets[0] = address(l1Erc20);
    calldatas[0] = proposalCalldata;
    values[0] = 0;

    // Create proposal
    uint256 proposalId =
      governorMock.propose(targets, values, calldatas, "Proposal: To inflate governance token");
    governorMock.cancel(
      targets, values, calldatas, keccak256(bytes("Proposal: To inflate governance token"))
    );

    vm.expectEmit();
    emit ProposalMetadataBridged(
      L2_CHAIN.wormholeChainId,
      address(l2GovernorMetadata),
      proposalId,
      governorMock.proposalSnapshot(proposalId),
      governorMock.proposalDeadline(proposalId),
      true
    );
    l1GovernorMetadataBridge.bridgeProposalMetadata{value: cost}(proposalId);

    vm.expectEmit();
    emit ProposalCanceled(proposalId);

    performDelivery();

    vm.selectFork(targetFork);
    L2GovernorMetadata.Proposal memory l2Proposal = l2GovernorMetadata.getProposal(proposalId);
    assertEq(l2Proposal.isCanceled, true, "isCanceled is incorrect");
  }

  function testFork_RevertWhen_ProposalIsMissing(uint256 _proposalId) public {
    l1GovernorMetadataBridge.initialize(address(l2GovernorMetadata));
    uint256 cost = l1GovernorMetadataBridge.quoteDeliveryCost(L1_CHAIN.wormholeChainId);
    vm.recordLogs();

    vm.expectRevert(WormholeL1GovernorMetadataBridge.InvalidProposalId.selector);
    l1GovernorMetadataBridge.bridgeProposalMetadata{value: cost}(_proposalId);
  }
}
