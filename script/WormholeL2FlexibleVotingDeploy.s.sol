// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {WormholeL1GovernorMetadataBridge} from "src/WormholeL1GovernorMetadataBridge.sol";
import {WormholeL2GovernorMetadata} from "src/WormholeL2GovernorMetadata.sol";

import {Script, stdJson} from "forge-std/Script.sol";

import {TimelockController} from "openzeppelin-flexible-voting/governance/TimelockController.sol";
import {ERC20Votes} from "openzeppelin-flexible-voting/token/ERC20/extensions/ERC20Votes.sol";
import {ERC20VotesComp} from
  "openzeppelin-flexible-voting/governance/extensions/GovernorVotesComp.sol";
import {ICompoundTimelock} from "openzeppelin-flexible-voting/vendor/compound/ICompoundTimelock.sol";

import {L1Block} from "src/L1Block.sol";
import {FakeERC20} from "src/FakeERC20.sol";
import {WormholeL1ERC20Bridge} from "src/WormholeL1ERC20Bridge.sol";
import {WormholeL2ERC20} from "src/WormholeL2ERC20.sol";
import {WormholeL2VoteAggregator} from "src/WormholeL2VoteAggregator.sol";
import {GovernorCompTestnet, GovernorTestnet} from "script/helpers/Governors.sol";

import {ScriptConstants} from "test/Constants.sol";
import {GovernorFlexibleVotingMock} from "test/mock/GovernorMock.sol";
import {ERC20VotesCompMock} from "test/mock/ERC20VotesCompMock.sol";

/// @notice Deploy all the necessary components for L2 Flexible Voting.
contract WormholeL2FlexibleVotingDeploy is Script, ScriptConstants {
  using stdJson for string;

  error ConfigurationError(string);

  event Configuration(
    address governorAddress,
    address l1TokenAddress,
    address l1BlockAddress,
    address contractOwner,
    string l2TokenName,
    string l2TokenSymbol,
    bool isCompToken
  );

  function run() public {
    setFallbackToDefaultRpcUrls(false);

    address l1BlockAddress = vm.envOr("L1_BLOCK_ADDRESS", address(0));
    string memory l2TokenName = vm.envOr("L2_TOKEN_NAME", string("Scopeapotomus"));
    string memory l2TokenSymbol = vm.envOr("L2_TOKEN_SYMBOL", string("SCOPE"));

    uint256 l1ForkId = vm.createSelectFork(L1_CHAIN.rpcUrl);
    (address governorAddress, address l1TokenAddress, bool isCompToken) = _setupGovernor();

    emit Configuration(
      governorAddress,
      l1TokenAddress,
      l1BlockAddress,
      vm.envOr("CONTRACT_OWNER", msg.sender),
      l2TokenName,
      l2TokenSymbol,
      isCompToken
    );

    // Create L1 bridge that mints the L2 token
    vm.broadcast();
    WormholeL1ERC20Bridge l1TokenBridge =
    new WormholeL1ERC20Bridge(l1TokenAddress, L1_CHAIN.wormholeRelayer, governorAddress, L1_CHAIN.wormholeChainId, L2_CHAIN.wormholeChainId, vm.envOr("CONTRACT_OWNER", msg.sender));

    // Create L1 metadata bridge that sends proposal metadata to L2
    vm.broadcast();
    WormholeL1GovernorMetadataBridge l1MetadataBridge =
    new WormholeL1GovernorMetadataBridge(governorAddress, L1_CHAIN.wormholeRelayer, L1_CHAIN.wormholeChainId, L2_CHAIN.wormholeChainId);

    vm.createSelectFork(L2_CHAIN.rpcUrl);
    emit Configuration(
      governorAddress,
      l1TokenAddress,
      l1BlockAddress,
      vm.envOr("CONTRACT_OWNER", msg.sender),
      l2TokenName,
      l2TokenSymbol,
      isCompToken
    );

    if (l1BlockAddress == address(0)) {
      vm.broadcast();
      L1Block l1Block = new L1Block();
      l1BlockAddress = address(l1Block);
    }

    // Create L2 ERC20Votes token
    vm.broadcast();
    WormholeL2ERC20 l2Token =
    new WormholeL2ERC20(l2TokenName, l2TokenSymbol, L2_CHAIN.wormholeRelayer, l1BlockAddress, L2_CHAIN.wormholeChainId, L1_CHAIN.wormholeChainId, vm.envOr("CONTRACT_OWNER", msg.sender));

    // Deploy the L2 vote aggregator
    vm.broadcast();
    WormholeL2VoteAggregator voteAggregator =
    new WormholeL2VoteAggregator(address(l2Token), L2_CHAIN.wormholeRelayer,  l1BlockAddress, L2_CHAIN.wormholeChainId, L1_CHAIN.wormholeChainId, vm.envOr("CONTRACT_OWNER", msg.sender));

    vm.broadcast();
    voteAggregator.setRegisteredSender(
      L1_CHAIN.wormholeChainId, _toWormholeAddress(address(l1MetadataBridge))
    );

    // Register L1 ERC20 bridge on L2 token
    vm.broadcast();
    l2Token.setRegisteredSender(
      L1_CHAIN.wormholeChainId, _toWormholeAddress(address(l1TokenBridge))
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
    l1MetadataBridge.initialize(address(voteAggregator));

    vm.broadcast();
    l1TokenBridge.initialize(address(l2Token));
  }

  /// @dev If a `Governor` and/or token address is not set this function will create a token and
  /// Governor. It will also create a Compound compatible `Governor` and token if the script is
  /// configured to do so.
  function _setupGovernor() internal returns (address, address, bool) {
    address governorAddress = vm.envOr("L1_GOVERNOR_ADDRESS", address(0));
    address l1TokenAddress = vm.envOr("L1_TOKEN_ADDRESS", address(0));
    bool isCompToken = vm.envOr("L1_COMP_TOKEN", false);

    // Revert missing governor address exists but not the token address
    if (governorAddress != address(0) && l1TokenAddress == address(0)) {
      revert ConfigurationError("Governor address has been specified without a token address.");
    }

    // Deploy L1 token on is not provided
    if (l1TokenAddress == address(0)) {
      if (isCompToken) {
        vm.broadcast();
        ERC20VotesCompMock deployedL1Token = new ERC20VotesCompMock("GovernanceComp", "GOVc");
        l1TokenAddress = address(deployedL1Token);
      } else {
        vm.broadcast();
        FakeERC20 deployedL1Token = new FakeERC20("Governance", "GOV");
        l1TokenAddress = address(deployedL1Token);
      }
    }
    // Deploy the L1 governor used in the L1 bridge
    if (governorAddress == address(0)) {
      vm.broadcast();
      TimelockController _timelock =
        new TimelockController(300 , new address[](0), new address[](0), address(0));

      if (isCompToken) {
        vm.broadcast();
        GovernorCompTestnet gov =
        new GovernorCompTestnet("Dao of Tests", ERC20VotesComp(l1TokenAddress), ICompoundTimelock(payable(_timelock)));
        ERC20Votes(gov.token()).delegate(address(this));
        governorAddress = address(gov);
      } else {
        vm.broadcast();
        GovernorTestnet gov =
          new GovernorTestnet("Dao of Tests", ERC20Votes(l1TokenAddress), _timelock);
        governorAddress = address(gov);
      }
    }
    return (governorAddress, l1TokenAddress, isCompToken);
  }
}
