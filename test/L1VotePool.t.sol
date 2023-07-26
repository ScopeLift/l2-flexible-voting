// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IGovernor} from "openzeppelin/governance/Governor.sol";
import {Vm, Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {WormholeRelayerBasicTest} from "wormhole-solidity-sdk/testing/WormholeRelayerTest.sol";

import {FakeERC20} from "src/FakeERC20.sol";
import {L1Block} from "src/L1Block.sol";
import {L1VotePool} from "src/L1VotePool.sol";
import {L2VoteAggregator} from "src/L2VoteAggregator.sol";
import {L2GovernorMetadata} from "src/L2GovernorMetadata.sol";
import {Constants} from "test/Constants.sol";
import {GovernorMetadataMock} from "test/mock/GovernorMetadataMock.sol";
import {GovernorMock} from "test/mock/GovernorMock.sol";

// Create test harness and perform a cross chain call
contract L1VotePoolHarness is L1VotePool, Test {
  constructor(address _relayer, address _governor) L1VotePool(_relayer, _governor) {}

  function receiveWormholeMessages(
    bytes memory payload,
    bytes[] memory additionalVaas,
    bytes32 callerAddr,
    uint16 sourceChain,
    bytes32 deliveryHash
  ) public override onlyRelayer {
    (uint256 proposalId,,,) =
      abi.decode(payload, (uint256, uint128, uint128, uint128));


    uint256 _deadline = governor.proposalDeadline(proposalId);
		  vm.roll(_deadline - 1);
		  console2.log(block.number);
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

  function createProposalVote(
    address fakeErc20,
    uint128 _against,
    uint128 _inFavor,
    uint128 _abstain,
	Vm vm
  ) public returns (uint256, uint256) {
    uint256 _proposalId = _createExampleProposal(fakeErc20);
    uint256 _deadline = governor.proposalDeadline(_proposalId);

    // _castVote(_proposalId, ProposalVote(_inFavor, _against, _abstain));
    return (_proposalId, _deadline - 1);
  }
}

contract L2VoteAggregatorHarness is L2VoteAggregator {
  constructor(
    address _votingToken,
    address _relayer,
    address _governorMetadata,
    address _l1BlockAddress,
    uint16 _targetChain
  ) L2VoteAggregator(_votingToken, _relayer, _governorMetadata, _l1BlockAddress, _targetChain) {}

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
    setTestnetForkChains(5, 6);
  }

  function setUpSource() public override {
    GovernorMetadataMock l2GovernorMetadata = new GovernorMetadataMock(wormholeCoreMumbai);
    L1Block l1Block = new L1Block();
    erc20 = new FakeERC20("GovExample", "GOV");
    l2VoteAggregator =
    new L2VoteAggregatorHarness(address(erc20), wormholeCoreMumbai, address(l2GovernorMetadata), address(l1Block), wormholeFujiId);
  }

  function setUpTarget() public override {
    l1Erc20 = new FakeERC20("GovExample", "GOV");
    GovernorMock gov = new GovernorMock("Testington Dao", l1Erc20);
    l1VotePool = new L1VotePoolHarness(wormholeCoreFuji, address(gov));
  }
}

// Maybe use a L2VoteAggregator test harness.
contract _ReceiveCastvoteWormholeMessages is L1VotePoolTest {
  function testFuzz_CorrectlyBridgeVoteAggregation(
    uint128 _against,
    uint128 _inFavor,
    uint128 _abstain
  ) public {
		  console2.log(block.number);
    vm.selectFork(targetFork);
    (uint256 _proposalId, uint256 activeBlockNumber) = l1VotePool.createProposalVote(address(l1Erc20), _against, _inFavor, _abstain, vm);
  // Ensure the proposal is now Active
  vm.roll(activeBlockNumber);
    IGovernor.ProposalState _state = l1VotePool.governor().state(_proposalId);
    assertEq(uint8(_state), uint8(IGovernor.ProposalState.Active), "Proposal is not active");
		  console2.log(activeBlockNumber);
	console2.logUint(uint8(_state));
	console2.logUint(_proposalId);


    vm.selectFork(sourceFork);
    l2VoteAggregator.initialize(address(l1VotePool));
    uint256 cost = l2VoteAggregator.quoteDeliveryCost(wormholeFujiId);
    vm.recordLogs();
    vm.deal(address(this), 10 ether);
    console2.logUint(_against);
    console2.logUint(_abstain);
    console2.logUint(_inFavor);
    console2.logUint(_proposalId);

    l2VoteAggregator.createProposalVote(_proposalId, _against, _inFavor, _abstain);
    l2VoteAggregator.bridgeVote{value: cost}(_proposalId);

	vm.roll(activeBlockNumber);

    performDelivery();

    vm.selectFork(targetFork);
		  console2.logUint(1111);
		  console2.log(block.number);
		  console2.log(activeBlockNumber);
	vm.roll(activeBlockNumber);
		  console2.log(block.number);
    (uint128 inFavor, uint128 against, uint128 abstain) = l1VotePool.proposalVotes(_proposalId);
    console2.logUint(against);
    console2.logUint(abstain);
    console2.logUint(inFavor);

    assertEq(against, _against, "Against value was not bridged correctly");
    assertEq(inFavor, _inFavor, "inFavor value was not bridged correctly");
    assertEq(abstain, _abstain, "abstain value was not bridged correctly");
  }
}
