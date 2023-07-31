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
  constructor(address _token, address _relayer, address _governor, uint16 _targetId)
    L1ERC20Bridge(_token, _relayer, _governor, _targetId)
  {}

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
  FakeERC20 fake;
  L1ERC20Bridge bridge;

  constructor() {
    setTestnetForkChains(6, 5);
  }

  function setUpSource() public override {
    fake = new FakeERC20("Hello", "WRLD");
    IGovernor gov = new GovernorMock("Testington Dao", fake);
    bridge = new L1ERC20Bridge(address(fake), wormholeCoreFuji, address(gov), wormholePolygonId);
  }

  function setUpTarget() public override {
    L1Block l1Block = new L1Block();
    l2Erc20 =
    new L2ERC20( "Hello", "WRLD", 0x0CBE91CF822c73C2315FB05100C2F714765d5c20, address(l1Block), wormholeFujiId);
  }
}

contract Constructor is Test, Constants {
  function testFork_CorrectlySetAllArgs(address l1Erc) public {
    FakeERC20 fake = new FakeERC20("Hello", "WRLD");
    IGovernor gov = new GovernorMock("Testington Dao", fake);
    L1ERC20Bridge bridge =
      new L1ERC20Bridge(address(l1Erc), wormholeCoreFuji, address(gov), wormholePolygonId);
    assertEq(address(bridge.L1_TOKEN()), l1Erc, "L1 token is not set correctly");
  }
}

contract Initialize is L1ERC20BridgeTest {
  function testFork_CorrectlyInitializeL2Token(address l2Erc20) public {
    bridge.initialize(address(l2Erc20));
    assertEq(bridge.L2_TOKEN_ADDRESS(), l2Erc20, "L2 token address is not setup correctly");
    assertEq(bridge.INITIALIZED(), true, "Bridge isn't initialized");
  }

  function testFork_InitializeL2AddressWhenAlreadyInitialized(address l2Erc20) public {
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

    fake.approve(address(bridge), _amount);
    fake.mint(address(this), _amount);
    vm.deal(address(this), 1 ether);

    bridge.deposit{value: cost}(address(this), _amount);

    performDelivery();

    vm.selectFork(targetFork);
    assertEq(l2Erc20.balanceOf(address(this)), _amount, "L2 token balance is not correct");
  }
}

// Top level receive is tested in L2ERC20 and L2VoteAggregator
contract _ReceiveWithdrawalWormholeMessages is Test, Constants {
  function testFuzzFork_CorrectlyReceiveWithdrawal(
    address _account,
    uint96 _amount,
    address l2Erc20
  ) public {
    vm.assume(_account != address(0));
    FakeERC20 fake = new FakeERC20("Hello", "WRLD");
    IGovernor gov = new GovernorMock("Testington Dao", fake);
    L1ERC20BridgeHarness bridge =
      new L1ERC20BridgeHarness(address(fake), wormholeCoreFuji, address(gov), wormholePolygonId);

    bridge.initialize(address(l2Erc20));
    fake.approve(address(this), _amount);
    fake.mint(address(this), _amount);
    vm.deal(address(this), 1 ether);

    fake.transfer(address(bridge), _amount);
    assertEq(fake.balanceOf(address(bridge)), _amount, "The Bridge balance is incorrect");

    bytes memory withdrawalCalldata = abi.encode(_account, _amount);
    bridge.receiveWithdrawalWormholeMessages(
      withdrawalCalldata, new bytes[](0), bytes32(""), uint16(0), bytes32("")
    );
    assertEq(fake.balanceOf(address(_account)), _amount, "The account balance is incorrect");
  }
}

contract _Withdraw is Test, Constants {
  function testFork_CorrectlyWithdrawTokens(address _account, uint96 _amount, address l2Erc20)
    public
  {
    vm.assume(_account != address(0));

    FakeERC20 fake = new FakeERC20("Hello", "WRLD");
    IGovernor gov = new GovernorMock("Testington Dao", fake);
    L1ERC20BridgeHarness bridge =
      new L1ERC20BridgeHarness(address(fake), wormholeCoreFuji, address(gov), wormholePolygonId);
    bridge.initialize(address(l2Erc20));

    fake.approve(address(this), _amount);
    fake.mint(address(this), _amount);
    vm.deal(address(this), 1 ether);

    fake.transfer(address(bridge), _amount);
    assertEq(fake.balanceOf(address(bridge)), _amount, "The Bridge balance is incorrect");

    bridge.withdraw(_account, _amount);
    assertEq(fake.balanceOf(address(_account)), _amount, "The account balance is incorrect");
  }
}
