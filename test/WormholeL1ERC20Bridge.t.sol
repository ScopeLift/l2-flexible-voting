// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IGovernor} from "openzeppelin/governance/Governor.sol";
import {WormholeRelayerBasicTest} from "wormhole-solidity-sdk/testing/WormholeRelayerTest.sol";
import {ERC20VotesComp} from
  "openzeppelin-flexible-voting/governance/extensions/GovernorVotesComp.sol";

import {L1Block} from "src/L1Block.sol";
import {FakeERC20} from "src/FakeERC20.sol";
import {WormholeL1ERC20Bridge} from "src/WormholeL1ERC20Bridge.sol";
import {WormholeL2ERC20} from "src/WormholeL2ERC20.sol";
import {L1ERC20BridgeHarness} from "test/harness/L1ERC20BridgeHarness.sol";
import {TestConstants} from "test/Constants.sol";
import {GovernorFlexibleVotingMock} from "test/mock/GovernorMock.sol";

contract L1ERC20BridgeTest is TestConstants, WormholeRelayerBasicTest {
  WormholeL2ERC20 l2Erc20;
  FakeERC20 l1Erc20;
  WormholeL1ERC20Bridge l1Erc20Bridge;
  GovernorFlexibleVotingMock gov;

  event VoteCast(
    address indexed voter,
    uint256 proposalId,
    uint256 voteAgainst,
    uint256 voteFor,
    uint256 voteAbstain
  );

  event TokenBridged(
    address indexed sender,
    address indexed targetAddress,
    uint256 indexed targetChain,
    uint256 amount,
    address targetToken
  );

  constructor() {
    setForkChains(TESTNET, L1_CHAIN.wormholeChainId, L2_CHAIN.wormholeChainId);
  }

  function setUpSource() public override {
    l1Erc20 = new FakeERC20("Hello", "WRLD");
    gov = new GovernorFlexibleVotingMock("Testington Dao", ERC20VotesComp(address(l1Erc20)));
    l1Erc20Bridge =
    new WormholeL1ERC20Bridge(address(l1Erc20), L1_CHAIN.wormholeRelayer, address(gov), L1_CHAIN.wormholeChainId, L2_CHAIN.wormholeChainId, msg.sender);
  }

  function setUpTarget() public override {
    L1Block l1Block = new L1Block();
    l2Erc20 =
    new WormholeL2ERC20( "Hello", "WRLD", L2_CHAIN.wormholeRelayer, address(l1Block), L2_CHAIN.wormholeChainId, L1_CHAIN.wormholeChainId, msg.sender);
    vm.prank(l2Erc20.owner());
    l2Erc20.setRegisteredSender(
      L1_CHAIN.wormholeChainId, bytes32(uint256(uint160(address(l1Erc20Bridge))))
    );
  }
}

contract Constructor is L1ERC20BridgeTest {
  function testForkFuzz_CorrectlySetAllArgs(address l1Erc) public {
    WormholeL1ERC20Bridge l1Erc20Bridge =
    new WormholeL1ERC20Bridge(address(l1Erc), L1_CHAIN.wormholeRelayer, address(gov), L1_CHAIN.wormholeChainId, L2_CHAIN.wormholeChainId, msg.sender);
    assertEq(address(l1Erc20Bridge.L1_TOKEN()), l1Erc, "L1 token is not set correctly");
  }
}

contract Initialize is L1ERC20BridgeTest {
  function testFork_CorrectlyInitializeL2Token(address l2Erc20) public {
    l1Erc20Bridge.initialize(address(l2Erc20));
    assertEq(l1Erc20Bridge.L2_TOKEN_ADDRESS(), l2Erc20, "L2 token address is not setup correctly");
    assertTrue(l1Erc20Bridge.INITIALIZED(), "Bridge isn't initialized");
  }

  function testFork_RevertWhen_AlreadyInitializedWithL2Erc20Address(address l2Erc20) public {
    l1Erc20Bridge.initialize(address(l2Erc20));

    vm.expectRevert(WormholeL1ERC20Bridge.AlreadyInitialized.selector);
    l1Erc20Bridge.initialize(address(l2Erc20));
  }
}

contract Deposit is L1ERC20BridgeTest {
  function testForkFuzz_CorrectlyDepositTokens(uint96 _amount) public {
    l1Erc20Bridge.initialize(address(l2Erc20));
    uint256 cost = l1Erc20Bridge.quoteDeliveryCost(L2_CHAIN.wormholeChainId);
    vm.recordLogs();

    l1Erc20.approve(address(l1Erc20Bridge), _amount);
    l1Erc20.mint(address(this), _amount);

    vm.expectEmit();
    emit TokenBridged(
      address(this), address(this), L2_CHAIN.wormholeChainId, _amount, address(l2Erc20)
    );
    l1Erc20Bridge.deposit{value: cost}(address(this), _amount);

    uint256 bridgeBalance = l1Erc20.balanceOf(address(l1Erc20Bridge));
    assertEq(bridgeBalance, _amount, "Amount has not been transfered to the bridge");

    vm.prank(L2_CHAIN.wormholeRelayer);
    performDelivery();

    vm.selectFork(targetFork);
    assertEq(l2Erc20.balanceOf(address(this)), _amount, "L2 token balance is not correct");
  }
}

// One test should get the emit event the ther should get the VoteCast
contract ReceiveWormholeMessages is L1ERC20BridgeTest {
  // Single L1 Vote
  function testFuzz_CastVoteOnL1(uint32 forVotes, uint32 againstVotes, uint32 abstainVotes) public {
    // Mint and transfer tokens to bridge
    l1Erc20.mint(address(this), type(uint96).max);
    l1Erc20.approve(address(this), type(uint96).max);
    l1Erc20.transferFrom(address(this), address(l1Erc20Bridge), type(uint96).max);

    address[] memory targets = new address[](1);
    bytes[] memory calldatas = new bytes[](1);
    uint256[] memory values = new uint256[](1);

    bytes memory proposalCalldata = abi.encode(FakeERC20.mint.selector, address(gov), 100_000);
    targets[0] = address(l1Erc20);
    calldatas[0] = proposalCalldata;
    values[0] = 0;

    uint256 proposalId = gov.propose(targets, values, calldatas, "Proposal: To inflate token");
    uint256 voteEnd = gov.proposalDeadline(proposalId);

    vm.roll(voteEnd - 1);
    bytes memory voteCalldata = abi.encode(proposalId, forVotes, againstVotes, abstainVotes);
    vm.prank(l1Erc20Bridge.owner());
    l1Erc20Bridge.setRegisteredSender(L1_CHAIN.wormholeChainId, MOCK_WORMHOLE_SERIALIZED_ADDRESS);

    vm.expectEmit();
    emit VoteCast(L2_CHAIN.wormholeRelayer, proposalId, forVotes, againstVotes, abstainVotes);

    vm.prank(L2_CHAIN.wormholeRelayer);
    l1Erc20Bridge.receiveWormholeMessages(
      voteCalldata,
      new bytes[](0),
      MOCK_WORMHOLE_SERIALIZED_ADDRESS,
      L1_CHAIN.wormholeChainId,
      bytes32("")
    );
  }
}

// Top level receive is tested in WormholeL2ERC20 and L2VoteAggregator
contract _ReceiveWithdrawalWormholeMessages is L1ERC20BridgeTest {
  event Withdraw(address indexed account, uint256 amount);

  function testForkFuzz_CorrectlyReceiveWithdrawal(
    address _account,
    uint96 _amount,
    address l2Erc20
  ) public {
    vm.assume(_account != address(0));
    FakeERC20 l1Erc20 = new FakeERC20("Hello", "WRLD");
    L1ERC20BridgeHarness l1Erc20Bridge =
    new L1ERC20BridgeHarness(address(l1Erc20), L1_CHAIN.wormholeRelayer, address(gov), L1_CHAIN.wormholeChainId, L2_CHAIN.wormholeChainId, msg.sender);

    l1Erc20Bridge.initialize(address(l2Erc20));
    l1Erc20.approve(address(this), _amount);
    l1Erc20.mint(address(this), _amount);
    vm.deal(address(this), 1 ether);

    l1Erc20.transfer(address(l1Erc20Bridge), _amount);
    assertEq(l1Erc20.balanceOf(address(l1Erc20Bridge)), _amount, "The Bridge balance is incorrect");

    bytes memory withdrawalCalldata = abi.encodePacked(_account, uint256(_amount));
    vm.expectEmit();
    emit Withdraw(_account, _amount);
    l1Erc20Bridge.exposed_receiveWithdrawalWormholeMessages(
      withdrawalCalldata, new bytes[](0), bytes32(""), uint16(0), bytes32("")
    );
    assertEq(l1Erc20.balanceOf(address(_account)), _amount, "The account balance is incorrect");
  }
}

contract _Withdraw is L1ERC20BridgeTest {
  event Withdraw(address indexed account, uint256 amount);

  function testFork_CorrectlyWithdrawTokens(address _account, uint224 _amount, address l2Erc20)
    public
  {
    vm.assume(_account != address(0));

    FakeERC20 l1Erc20 = new FakeERC20("Hello", "WRLD");
    L1ERC20BridgeHarness l1Erc20Bridge =
    new L1ERC20BridgeHarness(address(l1Erc20), L1_CHAIN.wormholeRelayer, address(gov), L1_CHAIN.wormholeChainId, L2_CHAIN.wormholeChainId, msg.sender);
    l1Erc20Bridge.initialize(address(l2Erc20));

    l1Erc20.approve(address(this), _amount);
    l1Erc20.mint(address(this), _amount);
    vm.deal(address(this), 1 ether);

    l1Erc20.transfer(address(l1Erc20Bridge), _amount);
    assertEq(l1Erc20.balanceOf(address(l1Erc20Bridge)), _amount, "The Bridge balance is incorrect");

    vm.expectEmit();
    emit Withdraw(_account, _amount);
    l1Erc20Bridge.withdraw(_account, _amount);
    assertEq(l1Erc20.balanceOf(address(_account)), _amount, "The account balance is incorrect");
  }
}
