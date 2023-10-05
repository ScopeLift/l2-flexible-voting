// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {WormholeRelayerBasicTest} from "wormhole-solidity-sdk/testing/WormholeRelayerTest.sol";
import {ERC20VotesComp} from
  "openzeppelin-flexible-voting/governance/extensions/GovernorVotesComp.sol";

import {L1Block} from "src/L1Block.sol";
import {L2GovernorMetadata} from "src/L2GovernorMetadata.sol";
import {WormholeL2GovernorMetadata} from "src/WormholeL2GovernorMetadata.sol";
import {FakeERC20} from "src/FakeERC20.sol";
import {L2VoteAggregator} from "src/L2VoteAggregator.sol";
import {WormholeL2VoteAggregator} from "src/WormholeL2VoteAggregator.sol";
import {L2GovernorMetadata} from "src/WormholeL2GovernorMetadata.sol";
import {TestConstants} from "test/Constants.sol";
import {GovernorMetadataMock} from "test/mock/GovernorMetadataMock.sol";
import {GovernorFlexibleVotingMock} from "test/mock/GovernorMock.sol";
import {WormholeL1VotePoolHarness} from "test/harness/WormholeL1VotePoolHarness.sol";
import {WormholeL2VoteAggregatorHarness} from "test/harness/WormholeL2VoteAggregatorHarness.sol";

contract L2VoteAggregatorTest is TestConstants, WormholeRelayerBasicTest {
  FakeERC20 l2Erc20;
  WormholeL2VoteAggregatorHarness l2VoteAggregator;
  FakeERC20 l1Erc20;
  WormholeL1VotePoolHarness l1VotePool;
  GovernorMetadataMock l2GovernorMetadata;
  L1Block l1Block;
  bytes32 l2VoteAggregatorWormholeAddress;

  event VoteCast(
    address indexed voter, uint256 proposalId, uint8 support, uint256 weight, string reason
  );

  event VoteCast(
    address indexed voter, uint256 proposalId, uint256 against, uint256 inFavor, uint256 abstain
  );
  event VoteBridged(
    uint256 indexed proposalId, uint256 voteAgainst, uint256 voteFor, uint256 voteAbstain
  );

  constructor() {
    setForkChains(TESTNET, L2_CHAIN.wormholeChainId, L1_CHAIN.wormholeChainId);
  }

  function setUpSource() public override {
    l2GovernorMetadata = new GovernorMetadataMock(L2_CHAIN.wormholeRelayer);
    l2Erc20 = new FakeERC20("GovExample", "GOV");
    l1Block = new L1Block();
    l2VoteAggregator =
    new WormholeL2VoteAggregatorHarness(address(l2Erc20), L2_CHAIN.wormholeRelayer, address(l2GovernorMetadata), address(l1Block), L2_CHAIN.wormholeChainId, L1_CHAIN.wormholeChainId);
  }

  function setUpTarget() public override {
    l1Erc20 = new FakeERC20("GovExample", "GOV");
    GovernorFlexibleVotingMock l1Governor =
      new GovernorFlexibleVotingMock("Testington Dao", ERC20VotesComp(address(l1Erc20)));
    l1VotePool = new WormholeL1VotePoolHarness(L1_CHAIN.wormholeRelayer, address(l1Governor));
    l2VoteAggregatorWormholeAddress = bytes32(uint256(uint160(address(l2VoteAggregator))));
    l1VotePool.setRegisteredSender(L2_CHAIN.wormholeChainId, l2VoteAggregatorWormholeAddress);
  }
}

contract Constructor is L2VoteAggregatorTest {
  function testFuzz_CorrectlySetsAllArgs() public {
    L1Block l1Block = new L1Block();
    GovernorMetadataMock l2GovernorMetadata = new GovernorMetadataMock(L2_CHAIN.wormholeRelayer);
    WormholeL2VoteAggregator l2VoteAggregator =
    new WormholeL2VoteAggregatorHarness(address(l2Erc20), L2_CHAIN.wormholeRelayer, address(l2GovernorMetadata), address(l1Block), L2_CHAIN.wormholeChainId, L1_CHAIN.wormholeChainId);

    assertEq(address(l1Block), address(l2VoteAggregator.L1_BLOCK()));
    assertEq(address(address(l2Erc20)), address(l2VoteAggregator.VOTING_TOKEN()));
    assertEq(address(address(l2GovernorMetadata)), address(l2VoteAggregator.GOVERNOR_METADATA()));
  }
}

/// @dev Although, the bridge method is in the `L2VoteAggregator` contract we test it here because
/// it will replicate the true end to end functionality
contract _bridgeVote is L2VoteAggregatorTest {
  function testFuzz_CorrectlyBridgeVoteAggregation(uint32 _against, uint32 _for, uint32 _abstain)
    public
  {
    vm.selectFork(targetFork);
    vm.assume(uint96(_against) + _for + _abstain != 0);

    l1Erc20.approve(address(l1VotePool), uint96(_against) + uint96(_for) + uint96(_abstain));
    l1Erc20.mint(address(this), uint96(_against) + uint96(_for) + uint96(_abstain));
    l1Erc20.delegate(address(l1VotePool));

    vm.roll(block.number + 1); // To checkpoint erc20 mint
    uint256 _proposalId = l1VotePool.createProposalVote(address(l1Erc20));

    vm.selectFork(sourceFork);
    l2VoteAggregator.initialize(address(l1VotePool));
    uint256 cost = l2VoteAggregator.quoteDeliveryCost(L1_CHAIN.wormholeChainId);
    vm.recordLogs();
    vm.deal(address(this), 10 ether);

    l2VoteAggregator.createProposalVote(_proposalId, _against, _for, _abstain);
    GovernorMetadataMock(address(l2VoteAggregator.GOVERNOR_METADATA())).createProposal(
      _proposalId, 3000
    );
    vm.expectEmit();
    emit VoteBridged(_proposalId, _against, _for, _abstain);
    l2VoteAggregator.bridgeVote{value: cost}(_proposalId);

    vm.expectEmit();
    emit VoteCast(L1_CHAIN.wormholeRelayer, _proposalId, _against, _for, _abstain);
    performDelivery();

    vm.selectFork(targetFork);
    (uint128 against, uint128 forVotes, uint128 abstain) = l1VotePool.proposalVotes(_proposalId);

    assertEq(against, _against, "Against value was not bridged correctly");
    assertEq(forVotes, _for, "For value was not bridged correctly");
    assertEq(abstain, _abstain, "abstain value was not bridged correctly");
  }
}
