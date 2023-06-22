// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {Script, stdJson} from "forge-std/Script.sol";
import {IERC20Mint} from "src/interfaces/IERC20Mint.sol";
import {IL1ERC20Bridge} from "src/interfaces/IL1ERC20Bridge.sol";
import {Constants} from "test/Constants.sol";

contract MintOnL2 is Script {
  using stdJson for string;

  function run() public {
    // Get L1 bridge tokken address
    string memory tokenFile = "broadcast/DeployFakeERC20.s.sol/43113/run-latest.json";
    string memory tokenJson = vm.readFile(tokenFile);

    address deployedL1Token = tokenJson.readAddress(".transactions[0].contractAddress");

    // Get L1 bridge address
    string memory bridgeFile = "broadcast/multi/Deploy.s.sol-latest/run.json";
    string memory bridgeJson = vm.readFile(bridgeFile);

    address l1Bridge = bridgeJson.readAddress(".deployments[1].transactions[0].contractAddress");

    setFallbackToDefaultRpcUrls(false);

    vm.createSelectFork(getChain("avalanche_fuji").rpcUrl);

    IL1ERC20Bridge bridge = IL1ERC20Bridge(address(l1Bridge));
    IERC20Mint erc20 = IERC20Mint(address(deployedL1Token));

    // Mint some L1 token
    vm.broadcast();
    erc20.mint(msg.sender, 100_000);

    // Approve L1 token to be sent to the bridge
    vm.broadcast();
    erc20.approve(address(bridge), 100_000_000);

    // Deposit minted L1 token into the bridge and mint send a token to L2
    vm.broadcast();
    bridge.deposit(msg.sender, 100_000);
  }
}
