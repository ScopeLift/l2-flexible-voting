// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {WormholeRelayerBasicTest} from "wormhole-solidity-sdk/testing/WormholeRelayerTest.sol";
import {ERC20VotesComp} from
  "openzeppelin-flexible-voting/governance/extensions/GovernorVotesComp.sol";

import {FakeERC20} from "src/FakeERC20.sol";
import {L1Block} from "src/L1Block.sol";
import {L1VotePool} from "src/L1VotePool.sol";
import {WormholeL2VoteAggregator} from "src/WormholeL2VoteAggregator.sol";

import {TestConstants} from "test/Constants.sol";
import {WormholeL1VotePoolHarness} from "test/harness/WormholeL1VotePoolHarness.sol";
import {WormholeL2VoteAggregatorHarness} from "test/harness/WormholeL2VoteAggregatorHarness.sol";
import {GovernorMetadataMock} from "test/mock/GovernorMetadataMock.sol";
import {GovernorFlexibleVotingMock} from "test/mock/GovernorMock.sol";

contract WormholeL1VotePoolTest is TestConstants, WormholeRelayerBasicTest {
  WormholeL1VotePoolHarness l1VotePool;
  WormholeL2VoteAggregatorHarness l2VoteAggregator;
  FakeERC20 l2Erc20;
  FakeERC20 l1Erc20;
  GovernorFlexibleVotingMock gov;

  event VoteCast(
    address indexed voter,
    uint256 proposalId,
    uint256 voteAgainst,
    uint256 voteFor,
    uint256 voteAbstain
  );
  event VoteBridged(
    uint256 indexed proposalId, uint256 voteAgainst, uint256 voteFor, uint256 voteAbstain
  );

  constructor() {
    setForkChains(TESTNET, L2_CHAIN.wormholeChainId, L1_CHAIN.wormholeChainId);
  }

  function setUpSource() public override {
    L1Block l1Block = new L1Block();
    l2Erc20 = new FakeERC20("GovExample", "GOV");
    l2VoteAggregator =
    new WormholeL2VoteAggregatorHarness(address(l2Erc20), L2_CHAIN.wormholeRelayer,  address(l1Block), L2_CHAIN.wormholeChainId, L1_CHAIN.wormholeChainId);
  }

  function setUpTarget() public override {
    l1Erc20 = new FakeERC20("GovExample", "GOV");
    gov = new GovernorFlexibleVotingMock("Testington Dao", ERC20VotesComp(address(l1Erc20)));
    l1VotePool = new WormholeL1VotePoolHarness(L1_CHAIN.wormholeRelayer, address(gov));
    l1VotePool.setRegisteredSender(
      L2_CHAIN.wormholeChainId, bytes32(uint256(uint160(address(l2VoteAggregator))))
    );
  }
}

contract Constructor is WormholeL1VotePoolTest {
  function testFuzz_CorrectlySetArguments() public {
    l1Erc20 = new FakeERC20("GovExample", "GOV");
    GovernorFlexibleVotingMock gov =
      new GovernorFlexibleVotingMock("Testington Dao", ERC20VotesComp(address(l1Erc20)));
    l1VotePool = new WormholeL1VotePoolHarness(L1_CHAIN.wormholeRelayer, address(gov));

    assertEq(address(l1VotePool.GOVERNOR()), address(gov), "Governor is not set correctly");
  }
}

contract _ReceiveCastVoteWormholeMessages is WormholeL1VotePoolTest {
  function testFuzz_CorrectlyBridgeVoteAggregation(
    uint32 _l2Against,
    uint32 _l2For,
    uint32 _l2Abstain
  ) public {
    vm.selectFork(targetFork);
    vm.assume(uint96(_l2Against) + _l2For + _l2Abstain != 0);

    uint96 totalVotes = uint96(_l2Against) + _l2For + _l2Abstain;

    l1Erc20.mint(address(this), totalVotes);
    l1Erc20.approve(address(this), totalVotes);
    l1Erc20.transferFrom(address(this), address(l1VotePool), totalVotes);

    vm.roll(block.number + 1); // To checkpoint erc20 mint
    uint256 _proposalId = l1VotePool.createProposalVote(address(l1Erc20));

    vm.selectFork(sourceFork);
    l2VoteAggregator.initialize(address(l1VotePool));
    uint256 cost = l2VoteAggregator.quoteDeliveryCost(L1_CHAIN.wormholeChainId);
    vm.recordLogs();
    vm.deal(address(this), 10 ether);

    l2VoteAggregator.createProposalVote(_proposalId, _l2Against, _l2For, _l2Abstain);
    l2VoteAggregator.createProposal(_proposalId, 3000);
    vm.expectEmit();
    emit VoteBridged(_proposalId, _l2Against, _l2For, _l2Abstain);
    l2VoteAggregator.bridgeVote{value: cost}(_proposalId);

    vm.expectEmit();
    emit VoteCast(L1_CHAIN.wormholeRelayer, _proposalId, _l2Against, _l2For, _l2Abstain);
    performDelivery();

    vm.selectFork(targetFork);
    (uint128 l1Against, uint128 l1For, uint128 l1Abstain) = l1VotePool.proposalVotes(_proposalId);

    assertEq(l1Against, _l2Against, "Against value was not bridged correctly");
    assertEq(l1For, _l2For, "For value was not bridged correctly");
    assertEq(l1Abstain, _l2Abstain, "abstain value was not bridged correctly");

    // Governor votes
    (uint256 totalAgainstVotes, uint256 totalForVotes, uint256 totalAbstainVotes) =
      gov.proposalVotes(_proposalId);
    assertEq(totalAgainstVotes, _l2Against, "Against value was not bridged correctly");
    assertEq(totalForVotes, _l2For, "For value was not bridged correctly");
    assertEq(totalAbstainVotes, _l2Abstain, "Abstain value was not bridged correctly");
  }

  function testFuzz_CorrectlyBridgeVoteAggregationWithExistingVote(
    uint32 _l2Against,
    uint32 _l2For,
    uint32 _l2Abstain,
    uint32 _l2NewAgainst,
    uint32 _l2NewFor,
    uint32 _l2NewAbstain
  ) public {
    vm.assume(_l2NewAgainst > _l2Against);
    vm.assume(_l2NewFor > _l2For);
    vm.assume(_l2NewAbstain > _l2Abstain);

    vm.selectFork(targetFork);
    uint96 totalVotes = uint96(_l2NewAgainst) + _l2NewFor + _l2NewAbstain;

    l1Erc20.mint(address(this), totalVotes);
    l1Erc20.approve(address(this), totalVotes);
    l1Erc20.transferFrom(address(this), address(l1VotePool), totalVotes);

    vm.roll(block.number + 1); // To checkpoint erc20 mint
    uint256 _proposalId =
      l1VotePool.createProposalVote(address(l1Erc20), _l2Against, _l2For, _l2Abstain);

    vm.selectFork(sourceFork);
    l2VoteAggregator.initialize(address(l1VotePool));
    uint256 cost = l2VoteAggregator.quoteDeliveryCost(L1_CHAIN.wormholeChainId);
    vm.recordLogs();
    vm.deal(address(this), 10 ether);

    l2VoteAggregator.createProposalVote(_proposalId, _l2NewAgainst, _l2NewFor, _l2NewAbstain);
    l2VoteAggregator.createProposal(_proposalId, 3000);
    vm.expectEmit();
    emit VoteBridged(_proposalId, _l2NewAgainst, _l2NewFor, _l2NewAbstain);
    l2VoteAggregator.bridgeVote{value: cost}(_proposalId);

    vm.expectEmit();
    emit VoteCast(
      L1_CHAIN.wormholeRelayer,
      _proposalId,
      _l2NewAgainst - _l2Against,
      _l2NewFor - _l2For,
      _l2NewAbstain - _l2Abstain
    );
    performDelivery();

    vm.selectFork(targetFork);
    (uint128 l1Against, uint128 l1For, uint128 l1Abstain) = l1VotePool.proposalVotes(_proposalId);

    assertEq(l1Against, _l2NewAgainst, "Against value was not bridged correctly");
    assertEq(l1For, _l2NewFor, "For value was not bridged correctly");
    assertEq(l1Abstain, _l2NewAbstain, "abstain value was not bridged correctly");

    // Governor votes
    (uint256 totalAgainstVotes, uint256 totalForVotes, uint256 totalAbstainVotes) =
      gov.proposalVotes(_proposalId);
    assertEq(totalAgainstVotes, _l2NewAgainst, "Total Against value is incorrect");
    assertEq(totalForVotes, _l2NewFor, "Total For value is incorrect");
    assertEq(totalAbstainVotes, _l2NewAbstain, "Total Abstain value is incorrect");
  }

  function testFuzz_RevertWhen_InvalidVoteHasBeenBridged(
    uint32 _l2Against,
    uint32 _l2For,
    uint32 _l2Abstain,
    uint32 _l2NewAgainst,
    uint32 _l2NewFor,
    uint32 _l2NewAbstain
  ) public {
    vm.assume(_l2NewAgainst < _l2Against);
    vm.assume(_l2NewFor < _l2For);
    vm.assume(_l2NewAbstain < _l2Abstain);

    vm.selectFork(targetFork);
    uint96 totalVotes = uint96(_l2Against) + _l2For + _l2Abstain;

    l1Erc20.mint(address(this), totalVotes);
    l1Erc20.approve(address(this), totalVotes);
    l1Erc20.transferFrom(address(this), address(l1VotePool), totalVotes);

    vm.roll(block.number + 1); // To checkpoint erc20 mint
    uint256 _proposalId =
      l1VotePool.createProposalVote(address(l1Erc20), _l2Against, _l2For, _l2Abstain);

    vm.prank(L1_CHAIN.wormholeRelayer);
    vm.expectRevert(L1VotePool.InvalidProposalVote.selector);
    l1VotePool.receiveWormholeMessages(
      abi.encode(_proposalId, _l2NewAgainst, _l2NewFor, _l2NewAbstain),
      new bytes[](0),
      bytes32(uint256(uint160(address(l2VoteAggregator)))),
      L2_CHAIN.wormholeChainId,
      bytes32(""),
      true
    );
  }

  function testFuzz_RevertWhen_VoteBeforeProposalStart(
    uint32 _l2Against,
    uint32 _l2For,
    uint32 _l2Abstain,
    uint32 _l2NewAgainst,
    uint32 _l2NewFor,
    uint32 _l2NewAbstain
  ) public {
    _l2NewAgainst = uint32(bound(_l2NewAgainst, 0, _l2Against));
    _l2NewFor = uint32(bound(_l2NewFor, 0, _l2For));
    _l2NewAbstain = uint32(bound(_l2NewAbstain, 0, _l2Abstain));

    vm.selectFork(targetFork);

    l1Erc20.approve(address(l1VotePool), uint96(_l2Against) + _l2For + _l2Abstain);
    l1Erc20.mint(address(this), uint96(_l2Against) + _l2For + _l2Abstain);

    uint256 _proposalId = l1VotePool.createProposalVote(address(l1Erc20));

    vm.prank(L1_CHAIN.wormholeRelayer);
    vm.expectRevert("Governor: vote not currently active");
    l1VotePool.receiveWormholeMessages(
      abi.encode(_proposalId, _l2NewAgainst, _l2NewFor, _l2NewAbstain),
      new bytes[](0),
      bytes32(uint256(uint160(address(l2VoteAggregator)))),
      L2_CHAIN.wormholeChainId,
      bytes32(""),
      false
    );
  }

  function testFuzz_RevertWhen_VoteAfterProposalEnd(
    uint32 _l2Against,
    uint32 _l2For,
    uint32 _l2Abstain,
    uint32 _l2NewAgainst,
    uint32 _l2NewFor,
    uint32 _l2NewAbstain
  ) public {
    _l2NewAgainst = uint32(bound(_l2NewAgainst, 0, _l2Against));
    _l2NewFor = uint32(bound(_l2NewFor, 0, _l2For));
    _l2NewAbstain = uint32(bound(_l2NewAbstain, 0, _l2Abstain));

    vm.selectFork(targetFork);

    l1Erc20.approve(address(l1VotePool), uint96(_l2Against) + _l2For + _l2Abstain);
    l1Erc20.mint(address(this), uint96(_l2Against) + _l2For + _l2Abstain);

    uint256 _proposalId = l1VotePool.createProposalVote(address(l1Erc20));
    l1VotePool._jumpToProposalEnd(_proposalId, 1);

    vm.prank(L1_CHAIN.wormholeRelayer);
    vm.expectRevert("Governor: vote not currently active");
    l1VotePool.receiveWormholeMessages(
      abi.encode(_proposalId, _l2NewAgainst, _l2NewFor, _l2NewAbstain),
      new bytes[](0),
      bytes32(uint256(uint160(address(l2VoteAggregator)))),
      L2_CHAIN.wormholeChainId,
      bytes32(""),
      false
    );
  }

  function testFuzz_RevertWhen_BridgeReceivedWhenCanceled(
    uint32 _l2Against,
    uint32 _l2For,
    uint32 _l2Abstain,
    uint32 _l2NewAgainst,
    uint32 _l2NewFor,
    uint32 _l2NewAbstain
  ) public {
    _l2NewAgainst = uint32(bound(_l2NewAgainst, 0, _l2Against));
    _l2NewFor = uint32(bound(_l2NewFor, 0, _l2For));
    _l2NewAbstain = uint32(bound(_l2NewAbstain, 0, _l2Abstain));

    vm.selectFork(targetFork);
    uint96 totalVotes = uint96(_l2Against) + _l2For + _l2Abstain;

    l1Erc20.mint(address(this), totalVotes);
    l1Erc20.approve(address(this), totalVotes);
    l1Erc20.transferFrom(address(this), address(l1VotePool), totalVotes);

    uint256 _proposalId = l1VotePool.createProposalVote(address(l1Erc20));
    l1VotePool.cancel(address(l1Erc20));
    l1VotePool._jumpToActiveProposal(_proposalId);

    vm.prank(L1_CHAIN.wormholeRelayer);
    vm.expectRevert("Governor: vote not currently active");
    l1VotePool.receiveWormholeMessages(
      abi.encode(_proposalId, _l2NewAgainst, _l2NewFor, _l2NewAbstain),
      new bytes[](0),
      bytes32(uint256(uint160(address(l2VoteAggregator)))),
      L2_CHAIN.wormholeChainId,
      bytes32(""),
      false
    );
  }
}
