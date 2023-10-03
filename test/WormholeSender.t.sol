// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IWormholeRelayer} from "wormhole/interfaces/relayer/IWormholeRelayer.sol";
import {WormholeRelayerBasicTest} from "wormhole-solidity-sdk/testing/WormholeRelayerTest.sol";

import {WormholeBase} from "src/WormholeBase.sol";
import {WormholeSender} from "src/WormholeSender.sol";
import {TestConstants} from "test/Constants.sol";

contract WormholeSenderHarness is WormholeSender {
  constructor(address _relayer, uint16 _sourceChain, uint16 _targetChain)
    WormholeBase(_relayer)
    WormholeSender(_sourceChain, _targetChain)
  {}

  function wormholeRelayer() public view returns (IWormholeRelayer) {
    return WORMHOLE_RELAYER;
  }
}

contract WormholeSenderTest is TestConstants, WormholeRelayerBasicTest {
  WormholeSender wormholeSender;

  constructor() {
    setForkChains(TESTNET, L1_CHAIN.wormholeChainId, L2_CHAIN.wormholeChainId);
  }

  function setUpSource() public override {
    wormholeSender =
    new WormholeSenderHarness(L1_CHAIN.wormholeRelayer, L1_CHAIN.wormholeChainId, L2_CHAIN.wormholeChainId);
  }

  function setUpTarget() public override {}
}

contract Constructor is WormholeSenderTest {
  function testForkFuzz_CorrectlySetsAllArgs(
    address _wormholeRelayer,
    uint16 _sourceChain,
    uint16 _targetChain
  ) public {
    WormholeSenderHarness newSender =
      new WormholeSenderHarness(_wormholeRelayer, _sourceChain, _targetChain);

    assertEq(
      address(newSender.wormholeRelayer()),
      _wormholeRelayer,
      "Wormhole relayer is not set correctly"
    );
    assertEq(newSender.REFUND_CHAIN(), _sourceChain, "Source chain is not correctly set");
    assertEq(newSender.TARGET_CHAIN(), _targetChain, "Target chain is not correctly set");
  }
}

contract QuoteDeliveryCost is WormholeSenderTest {
  function testFork_QuoteForDeliveryCostReturned() public {
    uint256 cost = wormholeSender.quoteDeliveryCost(L2_CHAIN.wormholeChainId);
    assertGt(cost, 0, "No cost was quoted");
  }
}
