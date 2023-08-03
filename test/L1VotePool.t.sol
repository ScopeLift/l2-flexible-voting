// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IGovernor} from "openzeppelin/governance/Governor.sol";
import {Vm, Test} from "forge-std/Test.sol";
import {WormholeRelayerBasicTest} from "wormhole-solidity-sdk/testing/WormholeRelayerTest.sol";

import {FakeERC20} from "src/FakeERC20.sol";
import {L1Block} from "src/L1Block.sol";
import {L1VotePool} from "src/L1VotePool.sol";
import {L2VoteAggregator} from "src/L2VoteAggregator.sol";
import {L2GovernorMetadata} from "src/L2GovernorMetadata.sol";
import {Constants} from "test/Constants.sol";
import {GovernorMetadataMock} from "test/mock/GovernorMetadataMock.sol";
import {GovernorFlexibleVotingMock} from "test/mock/GovernorMock.sol";
import {ERC20VotesComp} from
  "openzeppelin-flexible-voting/governance/extensions/GovernorVotesComp.sol";

contract L1VotePoolHarness is L1VotePool, Test {
  constructor(address _relayer, address _governor) L1VotePool(_relayer, _governor) {}

  function receiveWormholeMessages(
    bytes memory payload,
    bytes[] memory additionalVaas,
    bytes32 callerAddr,
    uint16 sourceChain,
    bytes32 deliveryHash
  ) public override onlyRelayer {
    (uint256 proposalId,,,) = abi.decode(payload, (uint256, uint128, uint128, uint128));
    _jumpToActiveProposal(proposalId);
    _receiveCastVoteWormholeMessages(payload, additionalVaas, callerAddr, sourceChain, deliveryHash);
  }

  function _createExampleProposal(address fakeErc20) internal returns (uint256) {
    bytes memory proposalCalldata = abi.encode(FakeERC20.mint.selector, address(governor), 100_000);

    address[] memory targets = new address[](1);
    bytes[] memory calldatas = new bytes[](1);
    uint256[] memory values = new uint256[](1);

    targets[0] = address(fakeErc20);
    calldatas[0] = proposalCalldata;
    values[0] = 0;

    return governor.propose(targets, values, calldatas, "Proposal: To inflate token");
  }

  function createProposalVote(address fakeErc20) public returns (uint256) {
    uint256 _proposalId = _createExampleProposal(fakeErc20);
    return _proposalId;
  }

  function createProposalVote(
    address fakeErc20,
    uint128 _against,
    uint128 _inFavor,
    uint128 _abstain
  ) public returns (uint256) {
    uint256 _proposalId = _createExampleProposal(fakeErc20);
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

contract L2VoteAggregatorHarness is L2VoteAggregator {
  constructor(
    address _votingToken,
    address _relayer,
    address _governorMetadata,
    address _l1BlockAddress,
    uint16 _sourceChain,
    uint16 _targetChain
  )
    L2VoteAggregator(
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

contract L1VotePoolTest is Constants, WormholeRelayerBasicTest {
  L1VotePoolHarness l1VotePool;
  L2VoteAggregatorHarness l2VoteAggregator;
  FakeERC20 erc20;
  FakeERC20 l1Erc20;

  constructor() {
    setForkChains(TESTNET, L2_CHAIN.wormholeChainId, L1_CHAIN.wormholeChainId);
  }

  function setUpSource() public override {
    GovernorMetadataMock l2GovernorMetadata = new GovernorMetadataMock(L2_CHAIN.wormholeRelayer);
    L1Block l1Block = new L1Block();
    erc20 = new FakeERC20("GovExample", "GOV");
    l2VoteAggregator =
    new L2VoteAggregatorHarness(address(erc20), L2_CHAIN.wormholeRelayer, address(l2GovernorMetadata), address(l1Block), L2_CHAIN.wormholeChainId, L1_CHAIN.wormholeChainId);
  }

  function setUpTarget() public override {
    l1Erc20 = new FakeERC20("GovExample", "GOV");
    GovernorFlexibleVotingMock gov =
      new GovernorFlexibleVotingMock("Testington Dao", ERC20VotesComp(address(l1Erc20)));
    l1VotePool = new L1VotePoolHarness(L1_CHAIN.wormholeRelayer, address(gov));
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

contract _ReceiveCastvoteWormholeMessages is L1VotePoolTest {
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
    l2VoteAggregator.bridgeVote{value: cost}(_proposalId);

    performDelivery();

    vm.selectFork(targetFork);
    (uint128 inFavor, uint128 against, uint128 abstain) = l1VotePool.proposalVotes(_proposalId);

    assertEq(against, _against, "Against value was not bridged correctly");
    assertEq(inFavor, _inFavor, "inFavor value was not bridged correctly");
    assertEq(abstain, _abstain, "abstain value was not bridged correctly");
  }

  function testFuzz_CorrectlyBridgeVoteAggregationWithExistingVote(
    uint32 _against,
    uint32 _inFavor,
    uint32 _abstain,
    uint32 _newAgainst,
    uint32 _newInFavor,
    uint32 _newAbstain
  ) public {
    vm.assume(_newAgainst > _against);
    vm.assume(_newInFavor > _inFavor);
    vm.assume(_newAbstain > _abstain);

    vm.selectFork(targetFork);

    l1Erc20.approve(
      address(l1VotePool), uint96(_newAgainst) + uint96(_newInFavor) + uint96(_newAbstain)
    );
    l1Erc20.mint(address(this), uint96(_newAgainst) + uint96(_newInFavor) + uint96(_newAbstain));
    l1Erc20.delegate(address(l1VotePool));

    vm.roll(block.number + 1); // To checkpoint erc20 mint
    uint256 _proposalId =
      l1VotePool.createProposalVote(address(l1Erc20), _against, _inFavor, _abstain);

    vm.selectFork(sourceFork);
    l2VoteAggregator.initialize(address(l1VotePool));
    uint256 cost = l2VoteAggregator.quoteDeliveryCost(L1_CHAIN.wormholeChainId);
    vm.recordLogs();
    vm.deal(address(this), 10 ether);

    l2VoteAggregator.createProposalVote(_proposalId, _newAgainst, _newInFavor, _newAbstain);
    l2VoteAggregator.bridgeVote{value: cost}(_proposalId);

    performDelivery();

    vm.selectFork(targetFork);
    (uint128 inFavor, uint128 against, uint128 abstain) = l1VotePool.proposalVotes(_proposalId);

    assertEq(against, _newAgainst, "Against value was not bridged correctly");
    assertEq(inFavor, _newInFavor, "inFavor value was not bridged correctly");
    assertEq(abstain, _newAbstain, "abstain value was not bridged correctly");
  }

  function testFuzz_InvalidVoteBridged(
    uint32 _against,
    uint32 _inFavor,
    uint32 _abstain,
    uint32 _newAgainst,
    uint32 _newInFavor,
    uint32 _newAbstain
  ) public {
    vm.assume(_newAgainst < _against);
    vm.assume(_newInFavor < _inFavor);
    vm.assume(_newAbstain < _abstain);

    vm.selectFork(targetFork);

    l1Erc20.approve(address(l1VotePool), uint96(_against) + uint96(_inFavor) + uint96(_abstain) + 1);
    l1Erc20.mint(address(this), uint96(_against) + uint96(_inFavor) + uint96(_abstain) + 1);
    l1Erc20.delegate(address(l1VotePool));

    vm.roll(block.number + 1); // To checkpoint erc20 mint
    uint256 _proposalId =
      l1VotePool.createProposalVote(address(l1Erc20), _against, _inFavor, _abstain);

    vm.prank(L1_CHAIN.wormholeRelayer);
    vm.expectRevert(L1VotePool.InvalidProposalVote.selector);
    l1VotePool.receiveWormholeMessages(
      abi.encode(_proposalId, _newAgainst, _newInFavor, _newAbstain),
      new bytes[](0),
      bytes32(""),
      uint16(0),
      bytes32("")
    );
  }
}
