// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

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
import {Constants} from "test/Constants.sol";
import {GovernorMetadataMock} from "test/mock/GovernorMetadataMock.sol";
import {GovernorFlexibleVotingMock} from "test/mock/GovernorMock.sol";

contract L1VotePoolHarness is WormholeL1VotePool, WormholeReceiver, Test {
  constructor(address _relayer, address _l1Governor)
    WormholeBase(_relayer)
    WormholeL1VotePool(_l1Governor)
  {}

  function receiveWormholeMessages(
    bytes memory payload,
    bytes[] memory additionalVaas,
    bytes32 sourceAddress,
    uint16 sourceChain,
    bytes32 deliveryHash
  ) public override onlyRelayer isRegisteredSender(sourceChain, sourceAddress) {
    (uint256 proposalId,,,) = abi.decode(payload, (uint256, uint128, uint128, uint128));
    _jumpToActiveProposal(proposalId);
    _receiveCastVoteWormholeMessages(
      payload, additionalVaas, sourceAddress, sourceChain, deliveryHash
    );
  }

  function _createExampleProposal(address l1Erc20) internal returns (uint256) {
    bytes memory proposalCalldata = abi.encode(FakeERC20.mint.selector, address(governor), 100_000);

    address[] memory targets = new address[](1);
    bytes[] memory calldatas = new bytes[](1);
    uint256[] memory values = new uint256[](1);

    targets[0] = address(l1Erc20);
    calldatas[0] = proposalCalldata;
    values[0] = 0;

    return governor.propose(targets, values, calldatas, "Proposal: To inflate token");
  }

  function createProposalVote(address l1Erc20) public returns (uint256) {
    uint256 _proposalId = _createExampleProposal(l1Erc20);
    return _proposalId;
  }

  function createProposalVote(address l1Erc20, uint128 _against, uint128 _inFavor, uint128 _abstain)
    public
    returns (uint256)
  {
    uint256 _proposalId = _createExampleProposal(l1Erc20);
    _jumpToActiveProposal(_proposalId);
    _receiveCastVoteWormholeMessages(
      abi.encode(_proposalId, _against, _inFavor, _abstain),
      new bytes[](0),
      bytes32(""),
      uint16(0),
      bytes32("")
    );
    return _proposalId;
  }

  function _jumpToActiveProposal(uint256 proposalId) internal {
    uint256 _deadline = governor.proposalDeadline(proposalId);
    vm.roll(_deadline - 1);
  }
}

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

  function createProposalVote(uint256 proposalId, uint128 against, uint128 inFavor, uint128 abstain)
    public
  {
    proposalVotes[proposalId] = ProposalVote(against, inFavor, abstain);
  }
}

contract L2VoteAggregatorTest is Constants, WormholeRelayerBasicTest {
  FakeERC20 l2Erc20;
  L2VoteAggregatorHarness l2VoteAggregator;
  FakeERC20 l1Erc20;
  L1VotePoolHarness l1VotePool;
  GovernorMetadataMock l2GovernorMetadata;
  L1Block l1Block;
  bytes32 l2VoteAggregatorWormholeAddress;

  event VoteCast(address indexed voter, uint256 proposalId, uint8 support, uint256 weight);

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

contract CastVote is L2VoteAggregatorTest {
  function testFuzz_RevertWhen_BeforeProposalStart(uint96 _amount, uint8 _support) public {
    vm.assume(_support < 2);
    l2Erc20.mint(address(this), _amount);

    vm.roll(block.number - 1);
    vm.expectRevert(L2VoteAggregator.ProposalInactive.selector);
    l2VoteAggregator.castVote(1, _support);
  }

  function testFuzz_RevertWhen_AfterCastWindow(
    uint96 _amount,
    uint8 _support,
    uint256 proposalId,
    uint64 timeToProposalEnd
  ) public {
    vm.assume(_support < 2);
    vm.assume(_amount != 0);
    vm.assume(l2VoteAggregator.CAST_VOTE_WINDOW() < timeToProposalEnd);
	timeToProposalEnd = uint64(bound(timeToProposalEnd, 0, type(uint64).max - block.number));

    // In the setup we use a mock contract rather than the actual contract
    L2GovernorMetadata.Proposal memory l2Proposal = GovernorMetadataMock(
      address(l2VoteAggregator.GOVERNOR_METADATA())
    ).createProposal(proposalId, timeToProposalEnd);

    vm.roll(l2Proposal.voteStart - 1);
    l2Erc20.mint(address(this), _amount);

    // Our active check is inclusinve so we need to add 1
    vm.roll(l2Proposal.voteStart + (timeToProposalEnd - l2VoteAggregator.CAST_VOTE_WINDOW()) + 1);
    vm.expectRevert(L2VoteAggregator.ProposalInactive.selector);
    l2VoteAggregator.castVote(proposalId, _support);
  }

  function testFuzz_RevertWhen_VoterHasAlreadyVoted(uint96 _amount, uint8 _support) public {
    vm.assume(_amount != 0);
    vm.assume(_support < 2);
    l2Erc20.mint(address(this), _amount);

    L2GovernorMetadata.Proposal memory l2Proposal =
      l2VoteAggregator.GOVERNOR_METADATA().getProposal(1);

    vm.roll(l2Proposal.voteStart + 1);
    l2VoteAggregator.castVote(1, _support);

    vm.expectRevert(L2VoteAggregator.AlreadyVoted.selector);
    l2VoteAggregator.castVote(1, _support);
  }

  function testFuzz_RevertWhen_VoterHasNoWeight(uint96 _amount, uint8 _support) public {
    vm.assume(_amount != 0);
    vm.assume(_support < 2);

    L2GovernorMetadata.Proposal memory l2Proposal =
      l2VoteAggregator.GOVERNOR_METADATA().getProposal(1);

    vm.roll(l2Proposal.voteStart + 1);
    vm.expectRevert(L2VoteAggregator.NoWeight.selector);
    l2VoteAggregator.castVote(1, _support);
  }

  function testFuzz_CorrectlyCastVoteAgainst(uint96 _amount) public {
    vm.assume(_amount != 0);
    l2Erc20.mint(address(this), _amount);

    L2GovernorMetadata.Proposal memory l2Proposal =
      l2VoteAggregator.GOVERNOR_METADATA().getProposal(1);

    vm.roll(l2Proposal.voteStart + 1);
    vm.expectEmit();
    emit VoteCast(address(this), 1, 0, _amount);

    l2VoteAggregator.castVote(1, 0);
    (uint256 against,,) = l2VoteAggregator.proposalVotes(1);
    assertEq(against, _amount, "Votes against is not correct");
  }

  function testFuzz_CorrectlyCastVoteAbstain(uint96 _amount) public {
    vm.assume(_amount != 0);
    l2Erc20.mint(address(this), _amount);

    L2GovernorMetadata.Proposal memory l2Proposal =
      l2VoteAggregator.GOVERNOR_METADATA().getProposal(1);

    vm.roll(l2Proposal.voteStart + 1);
    vm.expectEmit();
    emit VoteCast(address(this), 1, 2, _amount);

    l2VoteAggregator.castVote(1, 2);
    (,, uint256 abstain) = l2VoteAggregator.proposalVotes(1);

    assertEq(abstain, _amount, "Votes abstain is not correct");
  }

  function testFuzz_CorrectlyCastVoteInFavor(uint96 _amount) public {
    vm.assume(_amount != 0);
    l2Erc20.mint(address(this), _amount);

    L2GovernorMetadata.Proposal memory l2Proposal =
      l2VoteAggregator.GOVERNOR_METADATA().getProposal(1);

    vm.roll(l2Proposal.voteStart + 1);
    vm.expectEmit();
    emit VoteCast(address(this), 1, 1, _amount);

    l2VoteAggregator.castVote(1, 1);
    (, uint256 inFavor,) = l2VoteAggregator.proposalVotes(1);

    assertEq(inFavor, _amount, "Votes inFavor is not correct");
  }
}

contract BridgeVote is L2VoteAggregatorTest {
  function testFuzz_CorrectlyBridgeVoteAggregation(
    uint32 _against,
    uint32 _inFavor,
    uint32 _abstain
  ) public {
    vm.selectFork(targetFork);

    l1Erc20.approve(address(l1VotePool), uint96(_against) + uint96(_inFavor) + uint96(_abstain));
    l1Erc20.mint(address(this), uint96(_against) + uint96(_inFavor) + uint96(_abstain));
    l1Erc20.delegate(address(l1VotePool));

    vm.roll(block.number + 1); // To checkpoint erc20 mint
    uint256 _proposalId = l1VotePool.createProposalVote(address(l1Erc20));

    vm.selectFork(sourceFork);
    l2VoteAggregator.initialize(address(l1VotePool));
    uint256 cost = l2VoteAggregator.quoteDeliveryCost(L1_CHAIN.wormholeChainId);
    vm.recordLogs();
    vm.deal(address(this), 10 ether);

    l2VoteAggregator.createProposalVote(_proposalId, _against, _inFavor, _abstain);
    GovernorMetadataMock(address(l2VoteAggregator.GOVERNOR_METADATA())).createProposal(
      _proposalId, 3000
    );
    l2VoteAggregator.bridgeVote{value: cost}(_proposalId);

    performDelivery();

    vm.selectFork(targetFork);
    (uint128 inFavor, uint128 against, uint128 abstain) = l1VotePool.proposalVotes(_proposalId);

    assertEq(against, _against, "Against value was not bridged correctly");
    assertEq(inFavor, _inFavor, "inFavor value was not bridged correctly");
    assertEq(abstain, _abstain, "abstain value was not bridged correctly");
  }
}

contract InternalVotingPeriodEnd is L2VoteAggregatorTest {
  function testFuzz_InternalVotingPeriod(uint256 proposalId, uint256 voteStart, uint256 voteEnd)
    public
  {
    WormholeL2GovernorMetadata l2GovernorMetadata =
      new WormholeL2GovernorMetadata(L2_CHAIN.wormholeRelayer);
    l2GovernorMetadata.setRegisteredSender(
      L1_CHAIN.wormholeChainId, MOCK_WORMHOLE_SERIALIZED_ADDRESS
    );

    L2VoteAggregator aggregator =
    new WormholeL2VoteAggregator(address(l2Erc20), L2_CHAIN.wormholeRelayer, address(l2GovernorMetadata), address(l1Block), L2_CHAIN.wormholeChainId, L1_CHAIN.wormholeChainId);

    vm.assume(voteEnd > aggregator.CAST_VOTE_WINDOW());
    bytes memory proposalCalldata = abi.encode(proposalId, voteStart, voteEnd);

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
      new WormholeL2GovernorMetadata(L2_CHAIN.wormholeRelayer);
    l2GovernorMetadata.setRegisteredSender(
      L1_CHAIN.wormholeChainId, MOCK_WORMHOLE_SERIALIZED_ADDRESS
    );
    L2VoteAggregator aggregator =
    new WormholeL2VoteAggregator(address(l2Erc20), L2_CHAIN.wormholeRelayer, address(l2GovernorMetadata), address(l1Block), L2_CHAIN.wormholeChainId, L1_CHAIN.wormholeChainId);

    vm.assume(voteStart < block.number);
    vm.assume(voteEnd > aggregator.CAST_VOTE_WINDOW());
    vm.assume(voteEnd - aggregator.CAST_VOTE_WINDOW() > block.number); // Proposal must have a
      // voting block before the cast
      // period ends
    bytes memory proposalCalldata = abi.encode(proposalId, voteStart, voteEnd);
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
    uint64 voteEnd
  ) public {
    WormholeL2GovernorMetadata l2GovernorMetadata =
      new WormholeL2GovernorMetadata(L2_CHAIN.wormholeRelayer);
    l2GovernorMetadata.setRegisteredSender(
      L1_CHAIN.wormholeChainId, MOCK_WORMHOLE_SERIALIZED_ADDRESS
    );

    L2VoteAggregator aggregator =
    new WormholeL2VoteAggregator(address(l2Erc20), L2_CHAIN.wormholeRelayer, address(l2GovernorMetadata), address(l1Block), L2_CHAIN.wormholeChainId, L1_CHAIN.wormholeChainId);

    vm.assume(voteStart > 0); // Underflow because we subtract 1
    vm.assume(voteStart > block.number); // Block number must
    vm.assume(voteEnd > aggregator.CAST_VOTE_WINDOW()); // Without we have an underflow
    vm.assume(voteEnd - aggregator.CAST_VOTE_WINDOW() > voteStart); // Proposal must have a voting
      // block before the cast

    bytes memory proposalCalldata = abi.encode(proposalId, voteStart, voteEnd);
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
