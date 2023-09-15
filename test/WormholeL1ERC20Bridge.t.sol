// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IGovernor} from "openzeppelin/governance/Governor.sol";
import {WormholeRelayerBasicTest} from "wormhole-solidity-sdk/testing/WormholeRelayerTest.sol";

import {L1Block} from "src/L1Block.sol";
import {IERC20Mint} from "src/interfaces/IERC20Mint.sol";
import {FakeERC20} from "src/FakeERC20.sol";
import {WormholeL1ERC20Bridge} from "src/WormholeL1ERC20Bridge.sol";
import {WormholeL2ERC20} from "src/WormholeL2ERC20.sol";
import {Constants} from "test/Constants.sol";
import {GovernorMock} from "test/mock/GovernorMock.sol";

contract L1ERC20BridgeHarness is WormholeL1ERC20Bridge {
  constructor(
    address _l1Token,
    address _l1Relayer,
    address _l1Governor,
    uint16 _sourceId,
    uint16 _targetId
  ) WormholeL1ERC20Bridge(_l1Token, _l1Relayer, _l1Governor, _sourceId, _targetId) {}

  function withdraw(address account, uint256 amount) public {
    _withdraw(account, amount);
  }

  function receiveWithdrawalWormholeMessages(
    bytes memory payload,
    bytes[] memory additionalVaas,
    bytes32 callerAddr,
    uint16 sourceChain,
    bytes32 deliveryHash
  ) public {
    _receiveWithdrawalWormholeMessages(
      payload, additionalVaas, callerAddr, sourceChain, deliveryHash
    );
  }
}

contract L1ERC20BridgeTest is Constants, WormholeRelayerBasicTest {
  WormholeL2ERC20 l2Erc20;
  FakeERC20 l1Erc20;
  WormholeL1ERC20Bridge l1Erc20Bridge;

  constructor() {
    setForkChains(TESTNET, L1_CHAIN.wormholeChainId, L2_CHAIN.wormholeChainId);
  }

  function setUpSource() public override {
    l1Erc20 = new FakeERC20("Hello", "WRLD");
    IGovernor gov = new GovernorMock("Testington Dao", l1Erc20);
    l1Erc20Bridge =
    new WormholeL1ERC20Bridge(address(l1Erc20), L1_CHAIN.wormholeRelayer, address(gov), L1_CHAIN.wormholeChainId, L2_CHAIN.wormholeChainId);
  }

  function setUpTarget() public override {
    L1Block l1Block = new L1Block();
    l2Erc20 =
    new WormholeL2ERC20( "Hello", "WRLD", L2_CHAIN.wormholeRelayer, address(l1Block), L2_CHAIN.wormholeChainId, L1_CHAIN.wormholeChainId);
    l2Erc20.setRegisteredSender(
      L1_CHAIN.wormholeChainId, bytes32(uint256(uint160(address(l1Erc20Bridge))))
    );
  }
}

contract Constructor is Test, Constants {
  function testForkFuzz_CorrectlySetAllArgs(address l1Erc) public {
    FakeERC20 l1Erc20 = new FakeERC20("Hello", "WRLD");
    IGovernor gov = new GovernorMock("Testington Dao", l1Erc20);
    WormholeL1ERC20Bridge l1Erc20Bridge =
    new WormholeL1ERC20Bridge(address(l1Erc), L1_CHAIN.wormholeRelayer, address(gov), L1_CHAIN.wormholeChainId, L2_CHAIN.wormholeChainId);
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
    vm.deal(address(this), 1 ether);

    l1Erc20Bridge.deposit{value: cost}(address(this), _amount);

    uint256 bridgeBalance = l1Erc20.balanceOf(address(l1Erc20Bridge));
    assertEq(bridgeBalance, _amount, "Amount has not been transfered to the bridge");

    vm.prank(L2_CHAIN.wormholeRelayer);
    performDelivery();

    vm.selectFork(targetFork);
    assertEq(l2Erc20.balanceOf(address(this)), _amount, "L2 token balance is not correct");
  }
}

// Top level receive is tested in WormholeL2ERC20 and L2VoteAggregator
contract _ReceiveWithdrawalWormholeMessages is Test, Constants {
  function testForkFuzz_CorrectlyReceiveWithdrawal(
    address _account,
    uint96 _amount,
    address l2Erc20
  ) public {
    vm.assume(_account != address(0));
    FakeERC20 l1Erc20 = new FakeERC20("Hello", "WRLD");
    IGovernor gov = new GovernorMock("Testington Dao", l1Erc20);
    L1ERC20BridgeHarness l1Erc20Bridge =
    new L1ERC20BridgeHarness(address(l1Erc20), L1_CHAIN.wormholeRelayer, address(gov), L1_CHAIN.wormholeChainId, L2_CHAIN.wormholeChainId);

    l1Erc20Bridge.initialize(address(l2Erc20));
    l1Erc20.approve(address(this), _amount);
    l1Erc20.mint(address(this), _amount);
    vm.deal(address(this), 1 ether);

    l1Erc20.transfer(address(l1Erc20Bridge), _amount);
    assertEq(l1Erc20.balanceOf(address(l1Erc20Bridge)), _amount, "The Bridge balance is incorrect");

    bytes memory withdrawalCalldata = abi.encode(_account, _amount);
    l1Erc20Bridge.receiveWithdrawalWormholeMessages(
      withdrawalCalldata, new bytes[](0), bytes32(""), uint16(0), bytes32("")
    );
    assertEq(l1Erc20.balanceOf(address(_account)), _amount, "The account balance is incorrect");
  }
}

contract _Withdraw is Test, Constants {
  function testFork_CorrectlyWithdrawTokens(address _account, uint96 _amount, address l2Erc20)
    public
  {
    vm.assume(_account != address(0));

    FakeERC20 l1Erc20 = new FakeERC20("Hello", "WRLD");
    IGovernor gov = new GovernorMock("Testington Dao", l1Erc20);
    L1ERC20BridgeHarness l1Erc20Bridge =
    new L1ERC20BridgeHarness(address(l1Erc20), L1_CHAIN.wormholeRelayer, address(gov), L1_CHAIN.wormholeChainId, L2_CHAIN.wormholeChainId);
    l1Erc20Bridge.initialize(address(l2Erc20));

    l1Erc20.approve(address(this), _amount);
    l1Erc20.mint(address(this), _amount);
    vm.deal(address(this), 1 ether);

    l1Erc20.transfer(address(l1Erc20Bridge), _amount);
    assertEq(l1Erc20.balanceOf(address(l1Erc20Bridge)), _amount, "The Bridge balance is incorrect");

    l1Erc20Bridge.withdraw(_account, _amount);
    assertEq(l1Erc20.balanceOf(address(_account)), _amount, "The account balance is incorrect");
  }
}
