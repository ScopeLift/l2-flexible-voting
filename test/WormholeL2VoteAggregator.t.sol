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
import {WormholeL1VotePool} from "src/WormholeL1VotePool.sol";
import {L2VoteAggregator} from "src/L2VoteAggregator.sol";
import {WormholeL2VoteAggregator} from "src/WormholeL2VoteAggregator.sol";
import {L2GovernorMetadata} from "src/WormholeL2GovernorMetadata.sol";
import {WormholeBase} from "src/WormholeBase.sol";
import {WormholeReceiver} from "src/WormholeReceiver.sol";
import {TestConstants} from "test/Constants.sol";
import {GovernorMetadataMock} from "test/mock/GovernorMetadataMock.sol";
import {GovernorFlexibleVotingMock} from "test/mock/GovernorMock.sol";
import {L1VotePoolHarness} from "test/harness/L1VotePoolHarness.sol";

contract L2VoteAggregatorHarness is WormholeL2VoteAggregator {
  constructor(
    address _votingToken,
    address _relayer,
    address _governorMetadata,
    address _l1BlockAddress,
    uint16 _sourceChain,
    uint16 _targetChain
  )
    WormholeL2VoteAggregator(
      _votingToken,
      _relayer,
      _governorMetadata,
      _l1BlockAddress,
      _sourceChain,
      _targetChain
    )
  {}

  function createProposalVote(uint256 _proposalId, uint128 _against, uint128 _for, uint128 _abstain)
    public
  {
    proposalVotes[_proposalId] = ProposalVote(_against, _for, _abstain);
  }
}

contract L2VoteAggregatorTest is TestConstants, WormholeRelayerBasicTest {
  FakeERC20 l2Erc20;
  L2VoteAggregatorHarness l2VoteAggregator;
  FakeERC20 l1Erc20;
  L1VotePoolHarness l1VotePool;
  GovernorMetadataMock l2GovernorMetadata;
  L1Block l1Block;
  bytes32 l2VoteAggregatorWormholeAddress;

  event VoteCast(
    address indexed voter, uint256 proposalId, uint8 support, uint256 weight, string reason
  );

  event VoteCast(
    address indexed voter,
    uint256 indexed proposalId,
    uint256 against,
    uint256 inFavor,
    uint256 abstain
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
    new L2VoteAggregatorHarness(address(l2Erc20), L2_CHAIN.wormholeRelayer, address(l2GovernorMetadata), address(l1Block), L2_CHAIN.wormholeChainId, L1_CHAIN.wormholeChainId);
  }

  function setUpTarget() public override {
    l1Erc20 = new FakeERC20("GovExample", "GOV");
    GovernorFlexibleVotingMock l1Governor =
      new GovernorFlexibleVotingMock("Testington Dao", ERC20VotesComp(address(l1Erc20)));
    l1VotePool = new L1VotePoolHarness(L1_CHAIN.wormholeRelayer, address(l1Governor));
    l2VoteAggregatorWormholeAddress = bytes32(uint256(uint160(address(l2VoteAggregator))));
    l1VotePool.setRegisteredSender(L2_CHAIN.wormholeChainId, l2VoteAggregatorWormholeAddress);
  }
}

contract Constructor is L2VoteAggregatorTest {
  function testFuzz_CorrectlySetsAllArgs() public {
    L1Block l1Block = new L1Block();
    GovernorMetadataMock l2GovernorMetadata = new GovernorMetadataMock(L2_CHAIN.wormholeRelayer);
    WormholeL2VoteAggregator l2VoteAggregator =
    new L2VoteAggregatorHarness(address(l2Erc20), L2_CHAIN.wormholeRelayer, address(l2GovernorMetadata), address(l1Block), L2_CHAIN.wormholeChainId, L1_CHAIN.wormholeChainId);

    assertEq(address(l1Block), address(l2VoteAggregator.L1_BLOCK()));
    assertEq(address(address(l2Erc20)), address(l2VoteAggregator.VOTING_TOKEN()));
    assertEq(address(address(l2GovernorMetadata)), address(l2VoteAggregator.GOVERNOR_METADATA()));
  }
}

contract BridgeVote is L2VoteAggregatorTest {
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

contract InternalVotingPeriodEnd is L2VoteAggregatorTest {
  function testFuzz_InternalVotingPeriod(
    uint256 proposalId,
    uint256 voteStart,
    uint256 voteEnd,
    bool isCanceled
  ) public {
    WormholeL2GovernorMetadata l2GovernorMetadata =
      new WormholeL2GovernorMetadata(L2_CHAIN.wormholeRelayer, msg.sender);

    vm.prank(l2GovernorMetadata.owner());
    l2GovernorMetadata.setRegisteredSender(
      L1_CHAIN.wormholeChainId, MOCK_WORMHOLE_SERIALIZED_ADDRESS
    );

    L2VoteAggregator aggregator =
    new WormholeL2VoteAggregator(address(l2Erc20), L2_CHAIN.wormholeRelayer, address(l2GovernorMetadata), address(l1Block), L2_CHAIN.wormholeChainId, L1_CHAIN.wormholeChainId);

    voteEnd = bound(voteEnd, aggregator.CAST_VOTE_WINDOW(), type(uint256).max);
    bytes memory proposalCalldata = abi.encode(proposalId, voteStart, voteEnd, isCanceled);

    vm.prank(L2_CHAIN.wormholeRelayer);
    l2GovernorMetadata.receiveWormholeMessages(
      proposalCalldata,
      new bytes[](0),
      MOCK_WORMHOLE_SERIALIZED_ADDRESS,
      L1_CHAIN.wormholeChainId,
      bytes32("")
    );
    uint256 lastVotingBlock = aggregator.internalVotingPeriodEnd(proposalId);
    assertEq(lastVotingBlock, voteEnd - aggregator.CAST_VOTE_WINDOW());
  }
}

contract ProposalVoteActive is L2VoteAggregatorTest {
  function testFuzz_ProposalVoteIsActive(uint256 proposalId, uint64 voteStart, uint64 voteEnd)
    public
  {
    WormholeL2GovernorMetadata l2GovernorMetadata =
      new WormholeL2GovernorMetadata(L2_CHAIN.wormholeRelayer, msg.sender);

    vm.prank(l2GovernorMetadata.owner());
    l2GovernorMetadata.setRegisteredSender(
      L1_CHAIN.wormholeChainId, MOCK_WORMHOLE_SERIALIZED_ADDRESS
    );

    L2VoteAggregator aggregator =
    new WormholeL2VoteAggregator(address(l2Erc20), L2_CHAIN.wormholeRelayer, address(l2GovernorMetadata), address(l1Block), L2_CHAIN.wormholeChainId, L1_CHAIN.wormholeChainId);

    voteStart = uint64(bound(voteStart, 0, block.number));
    voteEnd = uint64(bound(voteEnd, block.number + aggregator.CAST_VOTE_WINDOW(), type(uint64).max));

    bytes memory proposalCalldata = abi.encode(proposalId, voteStart, voteEnd, false);
    vm.prank(L2_CHAIN.wormholeRelayer);
    l2GovernorMetadata.receiveWormholeMessages(
      proposalCalldata,
      new bytes[](0),
      MOCK_WORMHOLE_SERIALIZED_ADDRESS,
      L1_CHAIN.wormholeChainId,
      bytes32("")
    );
    uint256 lastVotingBlock = aggregator.internalVotingPeriodEnd(proposalId);

    vm.roll(lastVotingBlock);
    bool active = aggregator.proposalVoteActive(proposalId);
    assertEq(active, true, "Proposal is supposed to be active");
  }

  function testFuzz_ProposalVoteIsInactiveBefore(
    uint256 proposalId,
    uint64 voteStart,
    uint64 voteEnd,
    bool isCanceled
  ) public {
    WormholeL2GovernorMetadata l2GovernorMetadata =
      new WormholeL2GovernorMetadata(L2_CHAIN.wormholeRelayer, msg.sender);

    vm.prank(l2GovernorMetadata.owner());
    l2GovernorMetadata.setRegisteredSender(
      L1_CHAIN.wormholeChainId, MOCK_WORMHOLE_SERIALIZED_ADDRESS
    );

    L2VoteAggregator aggregator =
    new WormholeL2VoteAggregator(address(l2Erc20), L2_CHAIN.wormholeRelayer, address(l2GovernorMetadata), address(l1Block), L2_CHAIN.wormholeChainId, L1_CHAIN.wormholeChainId);

    vm.assume(voteStart > 0); // Prevent underflow because we subtract 1
    vm.assume(voteStart > block.number); // Block number must be greater than vote start
    vm.assume(voteEnd > aggregator.CAST_VOTE_WINDOW()); //  Prevent underflow
    vm.assume(voteEnd - aggregator.CAST_VOTE_WINDOW() > voteStart); // Proposal must have a voting
      // block before the cast

    bytes memory proposalCalldata = abi.encode(proposalId, voteStart, voteEnd, isCanceled);
    vm.prank(L2_CHAIN.wormholeRelayer);
    l2GovernorMetadata.receiveWormholeMessages(
      proposalCalldata,
      new bytes[](0),
      MOCK_WORMHOLE_SERIALIZED_ADDRESS,
      L1_CHAIN.wormholeChainId,
      bytes32("")
    );

    bool active = aggregator.proposalVoteActive(proposalId);
    assertFalse(active, "Proposal is supposed to be inactive");
  }

  function testFuzz_ProposalVoteIsCanceled(uint256 proposalId, uint64 voteStart, uint64 voteEnd)
    public
  {
    WormholeL2GovernorMetadata l2GovernorMetadata =
      new WormholeL2GovernorMetadata(L2_CHAIN.wormholeRelayer, msg.sender);
    vm.prank(l2GovernorMetadata.owner());
    l2GovernorMetadata.setRegisteredSender(
      L1_CHAIN.wormholeChainId, MOCK_WORMHOLE_SERIALIZED_ADDRESS
    );

    L2VoteAggregator aggregator =
    new WormholeL2VoteAggregator(address(l2Erc20), L2_CHAIN.wormholeRelayer, address(l2GovernorMetadata), address(l1Block), L2_CHAIN.wormholeChainId, L1_CHAIN.wormholeChainId);

    vm.assume(voteStart > 0); // Prevent underflow because we subtract 1
    vm.assume(voteStart > block.number); // Block number must be greater than vote start
    vm.assume(voteEnd > aggregator.CAST_VOTE_WINDOW()); // Prevent underflow

    bytes memory proposalCalldata = abi.encode(proposalId, voteStart, voteEnd, true);
    vm.prank(L2_CHAIN.wormholeRelayer);
    l2GovernorMetadata.receiveWormholeMessages(
      proposalCalldata,
      new bytes[](0),
      MOCK_WORMHOLE_SERIALIZED_ADDRESS,
      L1_CHAIN.wormholeChainId,
      bytes32("")
    );

    bool active = aggregator.proposalVoteActive(proposalId);
    assertFalse(active, "Proposal is supposed to be inactive");
  }
}
