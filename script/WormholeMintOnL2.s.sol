// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, stdJson} from "forge-std/Script.sol";
import {IERC20Mint} from "src/interfaces/IERC20Mint.sol";
import {IL1ERC20Bridge} from "src/interfaces/IL1ERC20Bridge.sol";
import {Constants} from "test/Constants.sol";
import {IWormholeRelayer} from "wormhole/interfaces/relayer/IWormholeRelayer.sol";
import {console2} from "forge-std/Test.sol";

/// @dev A script to test that the L1 bridging functionality works. It will call the bridge on L1
/// which will call the mint function on the L2 token.
contract WormholeMintOnL2 is Script, Constants {
  using stdJson for string;

  function run() public {
    string memory deployFile =
      "broadcast/multi/WormholeL2FlexibleVotingDeploy.s.sol-latest/run.json"; // multi deployment
    string memory deployJson = vm.readFile(deployFile);

    // Get L1 bridge token address
    address deployedL1Token =
      deployJson.readAddress(".deployments[0].transactions[0].contractAddress");

    // Get L1 bridge address
    address l1Bridge = deployJson.readAddress(".deployments[0].transactions[2].contractAddress");

    setFallbackToDefaultRpcUrls(false);

    vm.createSelectFork(L1_CHAIN.rpcUrl);

    IL1ERC20Bridge bridge = IL1ERC20Bridge(address(l1Bridge));
    IERC20Mint erc20 = IERC20Mint(address(deployedL1Token));

    // Mint some L1 token
    vm.broadcast();
    erc20.mint(msg.sender, 100_000);

    // Approve L1 token to be sent to the bridge
    vm.broadcast();
    erc20.approve(address(bridge), 100_000);

    uint256 cost = bridge.quoteDeliveryCost(L2_CHAIN.wormholeChainId);

    vm.broadcast();
    bridge.deposit{value: cost}(msg.sender, 100_000);
  }
}
