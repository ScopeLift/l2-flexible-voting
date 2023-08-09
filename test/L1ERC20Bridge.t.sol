// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IGovernor} from "openzeppelin/governance/Governor.sol";
import {WormholeRelayerBasicTest} from "wormhole-solidity-sdk/testing/WormholeRelayerTest.sol";

import {L1Block} from "src/L1Block.sol";
import {IERC20Mint} from "src/interfaces/IERC20Mint.sol";
import {FakeERC20} from "src/FakeERC20.sol";
import {L1ERC20Bridge} from "src/L1ERC20Bridge.sol";
import {L2ERC20} from "src/L2ERC20.sol";
import {Constants} from "test/Constants.sol";
import {GovernorMock} from "test/mock/GovernorMock.sol";

contract L1ERC20BridgeHarness is L1ERC20Bridge {
  constructor(
    address _token,
    address _relayer,
    address _governor,
    uint16 _sourceId,
    uint16 _targetId
  ) L1ERC20Bridge(_token, _relayer, _governor, _sourceId, _targetId) {}

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
  L2ERC20 l2Erc20;
  FakeERC20 l1Erc20;
  L1ERC20Bridge bridge;

  constructor() {
    setTestnetForkChains(6, 5);
  }

  function setUpSource() public override {
    l1Erc20 = new FakeERC20("Hello", "WRLD");
    IGovernor gov = new GovernorMock("Testington Dao", l1Erc20);
    bridge =
    new L1ERC20Bridge(address(l1Erc20), wormholeCoreFuji, address(gov), wormholeFujiId, wormholePolygonId);
  }

  function setUpTarget() public override {
    L1Block l1Block = new L1Block();
    l2Erc20 =
    new L2ERC20( "Hello", "WRLD", wormholeCoreMumbai, address(l1Block), wormholePolygonId, wormholeFujiId);
  }
}

contract Constructor is Test, Constants {
  function testFork_CorrectlySetAllArgs(address l1Erc) public {
    FakeERC20 l1Erc20 = new FakeERC20("Hello", "WRLD");
    IGovernor gov = new GovernorMock("Testington Dao", l1Erc20);
    L1ERC20Bridge bridge =
    new L1ERC20Bridge(address(l1Erc), wormholeCoreFuji, address(gov), wormholeFujiId, wormholePolygonId);
    assertEq(address(bridge.L1_TOKEN()), l1Erc, "L1 token is not set correctly");
  }
}

contract Initialize is L1ERC20BridgeTest {
  function testFork_CorrectlyInitializeL2Token(address l2Erc20) public {
    bridge.initialize(address(l2Erc20));
    assertEq(bridge.L2_TOKEN_ADDRESS(), l2Erc20, "L2 token address is not setup correctly");
    assertEq(bridge.INITIALIZED(), true, "Bridge isn't initialized");
  }

  function testFork_RevertWhen_AlreadyInitializedWithL2Erc20Address(address l2Erc20) public {
    bridge.initialize(address(l2Erc20));

    vm.expectRevert(L1ERC20Bridge.AlreadyInitialized.selector);
    bridge.initialize(address(l2Erc20));
  }
}

contract Deposit is L1ERC20BridgeTest {
  function testFork_CorrectlyDepositTokens(uint96 _amount) public {
    bridge.initialize(address(l2Erc20));
    uint256 cost = bridge.quoteDeliveryCost(wormholePolygonId);
    vm.recordLogs();

    l1Erc20.approve(address(bridge), _amount);
    l1Erc20.mint(address(this), _amount);
    vm.deal(address(this), 1 ether);

    bridge.deposit{value: cost}(address(this), _amount);

    vm.prank(wormholeCoreMumbai);
    performDelivery();

    vm.selectFork(targetFork);
    assertEq(l2Erc20.balanceOf(address(this)), _amount, "L2 token balance is not correct");
  }
}

// Top level receive is tested in L2ERC20 and L2VoteAggregator
contract _ReceiveWithdrawalWormholeMessages is Test, Constants {
  function testForkFuzz_CorrectlyReceiveWithdrawal(
    address _account,
    uint96 _amount,
    address l2Erc20
  ) public {
    vm.assume(_account != address(0));
    FakeERC20 l1Erc20 = new FakeERC20("Hello", "WRLD");
    IGovernor gov = new GovernorMock("Testington Dao", l1Erc20);
    L1ERC20BridgeHarness bridge =
    new L1ERC20BridgeHarness(address(l1Erc20), wormholeCoreFuji, address(gov), wormholeFujiId, wormholePolygonId);

    bridge.initialize(address(l2Erc20));
    l1Erc20.approve(address(this), _amount);
    l1Erc20.mint(address(this), _amount);
    vm.deal(address(this), 1 ether);

    l1Erc20.transfer(address(bridge), _amount);
    assertEq(l1Erc20.balanceOf(address(bridge)), _amount, "The Bridge balance is incorrect");

    bytes memory withdrawalCalldata = abi.encode(_account, _amount);
    bridge.receiveWithdrawalWormholeMessages(
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
    L1ERC20BridgeHarness bridge =
    new L1ERC20BridgeHarness(address(l1Erc20), wormholeCoreFuji, address(gov), wormholeFujiId, wormholePolygonId);
    bridge.initialize(address(l2Erc20));

    l1Erc20.approve(address(this), _amount);
    l1Erc20.mint(address(this), _amount);
    vm.deal(address(this), 1 ether);

    l1Erc20.transfer(address(bridge), _amount);
    assertEq(l1Erc20.balanceOf(address(bridge)), _amount, "The Bridge balance is incorrect");

    bridge.withdraw(_account, _amount);
    assertEq(l1Erc20.balanceOf(address(_account)), _amount, "The account balance is incorrect");
  }
}
