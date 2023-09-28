// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {WormholeL1GovernorMetadataBridge} from "src/WormholeL1GovernorMetadataBridge.sol";
import {WormholeL2GovernorMetadata} from "src/WormholeL2GovernorMetadata.sol";

import {Script, stdJson} from "forge-std/Script.sol";
import {IGovernor} from "openzeppelin/governance/Governor.sol";
import {ERC20Votes} from "openzeppelin/token/ERC20/extensions/ERC20Votes.sol";

import {L1Block} from "src/L1Block.sol";
import {FakeERC20} from "src/FakeERC20.sol";
import {WormholeL1ERC20Bridge} from "src/WormholeL1ERC20Bridge.sol";
import {WormholeL2ERC20} from "src/WormholeL2ERC20.sol";
import {WormholeL2VoteAggregator} from "src/WormholeL2VoteAggregator.sol";
import {Constants} from "test/Constants.sol";
import {GovernorMock} from "test/mock/GovernorMock.sol";

/// @notice Deploy all the necessary components for the L2 Flexible Voting
contract WormholeL2FlexibleVotingDeploy is Script, Constants {
  using stdJson for string;

  function run() public {
    setFallbackToDefaultRpcUrls(false);
    vm.createSelectFork(L1_CHAIN.rpcUrl);
    address GOVERNOR_ADDRESS = vm.envOr("DEPLOY_GOVERNOR", address(0));
    address L1_TOKEN_ADDRESS = vm.envOr("L1_TOKEN_ADDRESS", address(0));
    address L1_BLOCK_ADDRESS = vm.envOr("L1_BLOCK_ADDRESS", address(0));
    address CONTRACT_OWNER = vm.envOr("CONTRACT_OWNER", msg.sender);
    string memory L2_TOKEN_NAME = vm.envOr("L2_TOKEN_NAME", string("Scopeapotomus"));
    string memory L2_TOKEN_SYMBOL = vm.envOr("L2_TOKEN_SYMBOL", string("SCOPE"));

    // Deploy L1 token on is not provided
    if (L1_TOKEN_ADDRESS == address(0)) {
      vm.broadcast();
      ERC20Votes deployedL1Token = new FakeERC20("Governance", "GOV");
      L1_TOKEN_ADDRESS = address(deployedL1Token);
    }

    // Deploy the L1 governor used in the L1 bridge
    if (GOVERNOR_ADDRESS == address(0)) {
      vm.broadcast();
      IGovernor gov = new GovernorMock("Dao of Tests", ERC20Votes(L1_TOKEN_ADDRESS));
      GOVERNOR_ADDRESS = address(gov);
    }

    // Create L1 bridge that mints the L2 token
    vm.broadcast();
    WormholeL1ERC20Bridge l1TokenBridge =
    new WormholeL1ERC20Bridge(L1_TOKEN_ADDRESS, L1_CHAIN.wormholeRelayer, GOVERNOR_ADDRESS, L1_CHAIN.wormholeChainId, L2_CHAIN.wormholeChainId, CONTRACT_OWNER);

    // Create L1 metadata bridge that sends proposal metadata to L2
    vm.broadcast();
    WormholeL1GovernorMetadataBridge l1MetadataBridge =
    new WormholeL1GovernorMetadataBridge(GOVERNOR_ADDRESS, L1_CHAIN.wormholeRelayer, L1_CHAIN.wormholeChainId, L2_CHAIN.wormholeChainId);

    uint256 l1ForkId = vm.createSelectFork(L2_CHAIN.rpcUrl);

    if (L1_BLOCK_ADDRESS == address(0)) {
      vm.broadcast();
      L1Block l1Block = new L1Block();
      L1_BLOCK_ADDRESS = address(l1Block);
    }

    // Deploy the L2 metadata contract
    vm.broadcast();
    WormholeL2GovernorMetadata l2GovernorMetadata =
      new WormholeL2GovernorMetadata(L2_CHAIN.wormholeRelayer, CONTRACT_OWNER);

    // Create L2 ERC20Votes token
    vm.broadcast();
    WormholeL2ERC20 l2Token =
    new WormholeL2ERC20(L2_TOKEN_NAME, L2_TOKEN_SYMBOL, L2_CHAIN.wormholeRelayer, L1_BLOCK_ADDRESS, L2_CHAIN.wormholeChainId, L1_CHAIN.wormholeChainId, CONTRACT_OWNER);

    // Deploy the L2 vote aggregator
    vm.broadcast();
    WormholeL2VoteAggregator voteAggregator =
    new WormholeL2VoteAggregator(address(l2Token), L2_CHAIN.wormholeRelayer, address(l2GovernorMetadata), L1_BLOCK_ADDRESS, L2_CHAIN.wormholeChainId, L1_CHAIN.wormholeChainId);

    vm.broadcast();
    l2GovernorMetadata.setRegisteredSender(
      L1_CHAIN.wormholeChainId, _toWormholeAddress(address(l1MetadataBridge))
    );

    // Register L1 ERC20 bridge on L2 token
    vm.broadcast();
    l2Token.setRegisteredSender(
      L2_CHAIN.wormholeChainId, _toWormholeAddress(address(l1TokenBridge))
    );

    vm.broadcast();
    voteAggregator.initialize(address(l1TokenBridge));

    vm.broadcast();
    l2Token.initialize(address(l1TokenBridge));

    vm.selectFork(l1ForkId);

    // Register L2 token on ERC20 bridge
    vm.broadcast();
    l1TokenBridge.setRegisteredSender(
      L2_CHAIN.wormholeChainId, _toWormholeAddress(address(l2Token))
    );

    // Register Vote Aggregator on L1ERC20 bridge
    vm.broadcast();
    l1TokenBridge.setRegisteredSender(
      L2_CHAIN.wormholeChainId, _toWormholeAddress(address(voteAggregator))
    );

    vm.broadcast();
    l1MetadataBridge.initialize(address(l2GovernorMetadata));

    vm.broadcast();
    l1TokenBridge.initialize(address(l2Token));
  }
}
