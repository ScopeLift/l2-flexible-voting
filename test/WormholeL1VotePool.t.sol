// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Vm, Test} from "forge-std/Test.sol";
import {WormholeRelayerBasicTest} from "wormhole-solidity-sdk/testing/WormholeRelayerTest.sol";
import {ERC20VotesComp} from
  "openzeppelin-flexible-voting/governance/extensions/GovernorVotesComp.sol";

import {FakeERC20} from "src/FakeERC20.sol";
import {L1Block} from "src/L1Block.sol";
import {L1VotePool} from "src/L1VotePool.sol";
import {WormholeL1VotePool} from "src/WormholeL1VotePool.sol";
import {WormholeL2VoteAggregator} from "src/WormholeL2VoteAggregator.sol";
import {L2GovernorMetadata} from "src/WormholeL2GovernorMetadata.sol";
import {WormholeBase} from "src/WormholeBase.sol";
import {Constants} from "test/Constants.sol";
import {GovernorMetadataMock} from "test/mock/GovernorMetadataMock.sol";
import {GovernorFlexibleVotingMock} from "test/mock/GovernorMock.sol";
import {WormholeReceiver} from "src/WormholeReceiver.sol";
import {L1VotePoolHarness} from "test/harness/L1VotePoolHarness.sol";
import {L2VoteAggregatorHarness} from "test/harness/L2VoteAggregatorHarness.sol";

contract L1VotePoolTest is Constants, WormholeRelayerBasicTest {
  L1VotePoolHarness l1VotePool;
  L2VoteAggregatorHarness l2VoteAggregator;
  FakeERC20 l2Erc20;
  FakeERC20 l1Erc20;

  constructor() {
    setForkChains(TESTNET, L2_CHAIN.wormholeChainId, L1_CHAIN.wormholeChainId);
  }

  function setUpSource() public override {
    GovernorMetadataMock l2GovernorMetadata = new GovernorMetadataMock(L2_CHAIN.wormholeRelayer);
    L1Block l1Block = new L1Block();
    l2Erc20 = new FakeERC20("GovExample", "GOV");
    l2VoteAggregator =
    new L2VoteAggregatorHarness(address(l2Erc20), L2_CHAIN.wormholeRelayer, address(l2GovernorMetadata), address(l1Block), L2_CHAIN.wormholeChainId, L1_CHAIN.wormholeChainId);
  }

  function setUpTarget() public override {
    l1Erc20 = new FakeERC20("GovExample", "GOV");
    GovernorFlexibleVotingMock gov =
      new GovernorFlexibleVotingMock("Testington Dao", ERC20VotesComp(address(l1Erc20)));
    l1VotePool = new L1VotePoolHarness(L1_CHAIN.wormholeRelayer, address(gov));
    l1VotePool.setRegisteredSender(
      L2_CHAIN.wormholeChainId, bytes32(uint256(uint160(address(l2VoteAggregator))))
    );
  }
}

contract Constructor is L1VotePoolTest {
  function testFuzz_CorrectlySetArguments() public {
    l1Erc20 = new FakeERC20("GovExample", "GOV");
    GovernorFlexibleVotingMock gov =
      new GovernorFlexibleVotingMock("Testington Dao", ERC20VotesComp(address(l1Erc20)));
    l1VotePool = new L1VotePoolHarness(L1_CHAIN.wormholeRelayer, address(gov));

    assertEq(address(l1VotePool.governor()), address(gov), "Governor is not set correctly");
  }
}

contract _ReceiveCastVoteWormholeMessages is L1VotePoolTest {
  function testFuzz_CorrectlyBridgeVoteAggregation(
    uint32 _l2Against,
    uint32 _l2InFavor,
    uint32 _l2Abstain
  ) public {
    vm.selectFork(targetFork);

    l1Erc20.approve(address(l1VotePool), uint96(_l2Against) + _l2InFavor + _l2Abstain);
    l1Erc20.mint(address(this), uint96(_l2Against) + _l2InFavor + _l2Abstain);
    l1Erc20.delegate(address(l1VotePool));

    vm.roll(block.number + 1); // To checkpoint erc20 mint
    uint256 _proposalId = l1VotePool.createProposalVote(address(l1Erc20));

    vm.selectFork(sourceFork);
    l2VoteAggregator.initialize(address(l1VotePool));
    uint256 cost = l2VoteAggregator.quoteDeliveryCost(L1_CHAIN.wormholeChainId);
    vm.recordLogs();
    vm.deal(address(this), 10 ether);

    l2VoteAggregator.createProposalVote(_proposalId, _l2Against, _l2InFavor, _l2Abstain);
    GovernorMetadataMock(address(l2VoteAggregator.GOVERNOR_METADATA())).createProposal(
      _proposalId, 3000
    );
    l2VoteAggregator.bridgeVote{value: cost}(_proposalId);

    performDelivery();

    vm.selectFork(targetFork);
    (uint128 l1InFavor, uint128 l1Against, uint128 l1Abstain) =
      l1VotePool.proposalVotes(_proposalId);

    assertEq(l1Against, _l2Against, "Against value was not bridged correctly");
    assertEq(l1InFavor, _l2InFavor, "inFavor value was not bridged correctly");
    assertEq(l1Abstain, _l2Abstain, "abstain value was not bridged correctly");
  }

  function testFuzz_CorrectlyBridgeVoteAggregationWithExistingVote(
    uint32 _l2Against,
    uint32 _l2InFavor,
    uint32 _l2Abstain,
    uint32 _l2NewAgainst,
    uint32 _l2NewInFavor,
    uint32 _l2NewAbstain
  ) public {
    vm.assume(_l2NewAgainst > _l2Against);
    vm.assume(_l2NewInFavor > _l2InFavor);
    vm.assume(_l2NewAbstain > _l2Abstain);

    vm.selectFork(targetFork);

    l1Erc20.approve(address(l1VotePool), uint96(_l2NewAgainst) + _l2NewInFavor + _l2NewAbstain);
    l1Erc20.mint(address(this), uint96(_l2NewAgainst) + _l2NewInFavor + _l2NewAbstain);
    l1Erc20.delegate(address(l1VotePool));

    vm.roll(block.number + 1); // To checkpoint erc20 mint
    uint256 _proposalId =
      l1VotePool.createProposalVote(address(l1Erc20), _l2Against, _l2InFavor, _l2Abstain);

    vm.selectFork(sourceFork);
    l2VoteAggregator.initialize(address(l1VotePool));
    uint256 cost = l2VoteAggregator.quoteDeliveryCost(L1_CHAIN.wormholeChainId);
    vm.recordLogs();
    vm.deal(address(this), 10 ether);

    l2VoteAggregator.createProposalVote(_proposalId, _l2NewAgainst, _l2NewInFavor, _l2NewAbstain);
    GovernorMetadataMock(address(l2VoteAggregator.GOVERNOR_METADATA())).createProposal(
      _proposalId, 3000
    );
    l2VoteAggregator.bridgeVote{value: cost}(_proposalId);

    performDelivery();

    vm.selectFork(targetFork);
    (uint128 l1InFavor, uint128 l1Against, uint128 l1Abstain) =
      l1VotePool.proposalVotes(_proposalId);

    assertEq(l1Against, _l2NewAgainst, "Against value was not bridged correctly");
    assertEq(l1InFavor, _l2NewInFavor, "inFavor value was not bridged correctly");
    assertEq(l1Abstain, _l2NewAbstain, "abstain value was not bridged correctly");
  }

  function testFuzz_RevertWhen_InvalidVoteHasBeenBridged(
    uint32 _l2Against,
    uint32 _l2InFavor,
    uint32 _l2Abstain,
    uint32 _l2NewAgainst,
    uint32 _l2NewInFavor,
    uint32 _l2NewAbstain
  ) public {
    vm.assume(_l2NewAgainst < _l2Against);
    vm.assume(_l2NewInFavor < _l2InFavor);
    vm.assume(_l2NewAbstain < _l2Abstain);

    vm.selectFork(targetFork);

    l1Erc20.approve(address(l1VotePool), uint96(_l2Against) + _l2InFavor + _l2Abstain + 1);
    l1Erc20.mint(address(this), uint96(_l2Against) + _l2InFavor + _l2Abstain + 1);
    l1Erc20.delegate(address(l1VotePool));

    vm.roll(block.number + 1); // To checkpoint erc20 mint
    uint256 _proposalId =
      l1VotePool.createProposalVote(address(l1Erc20), _l2Against, _l2InFavor, _l2Abstain);

    vm.prank(L1_CHAIN.wormholeRelayer);
    vm.expectRevert(L1VotePool.InvalidProposalVote.selector);
    l1VotePool.receiveWormholeMessages(
      abi.encode(_proposalId, _l2NewAgainst, _l2NewInFavor, _l2NewAbstain),
      new bytes[](0),
      bytes32(uint256(uint160(address(l2VoteAggregator)))),
      L2_CHAIN.wormholeChainId,
      bytes32(""),
      true
    );
  }

  function testFuzz_RevertWhen_VoteBeforeProposalStart(
    uint32 _l2Against,
    uint32 _l2InFavor,
    uint32 _l2Abstain,
    uint32 _l2NewAgainst,
    uint32 _l2NewInFavor,
    uint32 _l2NewAbstain
  ) public {
    _l2NewAgainst = uint32(bound(_l2NewAgainst, 0, _l2Against));
    _l2NewInFavor = uint32(bound(_l2NewInFavor, 0, _l2InFavor));
    _l2NewAbstain = uint32(bound(_l2NewAbstain, 0, _l2Abstain));

    vm.selectFork(targetFork);

    l1Erc20.approve(address(l1VotePool), uint96(_l2Against) + _l2InFavor + _l2Abstain);
    l1Erc20.mint(address(this), uint96(_l2Against) + _l2InFavor + _l2Abstain);
    l1Erc20.delegate(address(l1VotePool));

    uint256 _proposalId = l1VotePool.createProposalVote(address(l1Erc20));

    vm.prank(L1_CHAIN.wormholeRelayer);
    vm.expectRevert("Governor: vote not currently active");
    l1VotePool.receiveWormholeMessages(
      abi.encode(_proposalId, _l2NewAgainst, _l2NewInFavor, _l2NewAbstain),
      new bytes[](0),
      bytes32(uint256(uint160(address(l2VoteAggregator)))),
      L2_CHAIN.wormholeChainId,
      bytes32(""),
      false
    );
  }

  function testFuzz_RevertWhen_VoteAfterProposalEnd(
    uint32 _l2Against,
    uint32 _l2InFavor,
    uint32 _l2Abstain,
    uint32 _l2NewAgainst,
    uint32 _l2NewInFavor,
    uint32 _l2NewAbstain
  ) public {
    _l2NewAgainst = uint32(bound(_l2NewAgainst, 0, _l2Against));
    _l2NewInFavor = uint32(bound(_l2NewInFavor, 0, _l2InFavor));
    _l2NewAbstain = uint32(bound(_l2NewAbstain, 0, _l2Abstain));

    vm.selectFork(targetFork);

    l1Erc20.approve(address(l1VotePool), uint96(_l2Against) + _l2InFavor + _l2Abstain);
    l1Erc20.mint(address(this), uint96(_l2Against) + _l2InFavor + _l2Abstain);
    l1Erc20.delegate(address(l1VotePool));

    uint256 _proposalId = l1VotePool.createProposalVote(address(l1Erc20));
    l1VotePool._jumpToProposalEnd(_proposalId, 1);

    vm.prank(L1_CHAIN.wormholeRelayer);
    vm.expectRevert("Governor: vote not currently active");
    l1VotePool.receiveWormholeMessages(
      abi.encode(_proposalId, _l2NewAgainst, _l2NewInFavor, _l2NewAbstain),
      new bytes[](0),
      bytes32(uint256(uint160(address(l2VoteAggregator)))),
      L2_CHAIN.wormholeChainId,
      bytes32(""),
      false
    );
  }
}
