// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, stdJson} from "forge-std/Script.sol";
import {IGovernor} from "openzeppelin/governance/Governor.sol";
import {ERC20Votes} from "openzeppelin/token/ERC20/extensions/ERC20Votes.sol";

import {FakeERC20} from "src/FakeERC20.sol";
import {L1Block} from "src/L1Block.sol";
import {WormholeL1ERC20Bridge} from "src/WormholeL1ERC20Bridge.sol";
import {WormholeL2ERC20} from "src/WormholeL2ERC20.sol";
import {Constants} from "test/Constants.sol";
import {GovernorMock} from "test/mock/GovernorMock.sol";

/// @notice Deploy L1 bridge and corresponding token to be minted on L2
contract Deploy is Script, Constants {
  using stdJson for string;

  function run() public {
    setFallbackToDefaultRpcUrls(false);

    uint256 l2ForkId = vm.createSelectFork(L2_CHAIN.rpcUrl);

    // Create L1 block contract
    vm.broadcast();
    L1Block l1Block = new L1Block();

    // Create L2 ERC20Votes token
    vm.broadcast();
    WormholeL2ERC20 l2Token =
    new WormholeL2ERC20("Scopeapotomus", "SCOPE", L2_CHAIN.wormholeRelayer, address(l1Block), L2_CHAIN.wormholeChainId, L1_CHAIN.wormholeChainId);

    uint256 l1ForkId = vm.createSelectFork(L1_CHAIN.rpcUrl);
    vm.broadcast();
    FakeERC20 l1Token = new FakeERC20("Governance", "GOV");

    // Deploy the L1 governor used in the L1 bridge
    vm.broadcast();
    IGovernor gov = new GovernorMock("Testington Dao", l1Token);

    // Create L1 bridge that mints the L2 token
    vm.broadcast();
    WormholeL1ERC20Bridge bridge =
    new WormholeL1ERC20Bridge(address(l1Token), L1_CHAIN.wormholeRelayer, address(gov), L1_CHAIN.wormholeChainId, L2_CHAIN.wormholeChainId);

    // Tell the bridge its corresponding L2 token
    vm.broadcast();
    bridge.initialize(address(l2Token));

    // vm.cselectFork(L2_CHAIN.chainId);
    vm.selectFork(l2ForkId);
    vm.broadcast();
    l2Token.setRegisteredSender(
      L2_CHAIN.wormholeChainId, _toWormholeAddress(address(bridge))
    );
  }
}
