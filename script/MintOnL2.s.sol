// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {Script, stdJson} from "forge-std/Script.sol";
import {IERC20Mint} from "src/interfaces/IERC20Mint.sol";
import {IL1ERC20Bridge} from "src/interfaces/IL1ERC20Bridge.sol";
import {Constants} from "test/Constants.sol";
import {IWormholeRelayer} from "wormhole/interfaces/relayer/IWormholeRelayer.sol";

/// @dev A script to test that the L1 bridging functionality works. It will call the bridge on L1
/// which will call the mint function on the L2 token.
contract MintOnL2 is Script, Constants {
  using stdJson for string;

  function run() public {
    // Get L1 bridge token address
    string memory tokenFile = "broadcast/DeployFakeERC20.s.sol/43113/run-latest.json";
    string memory tokenJson = vm.readFile(tokenFile);

    address deployedL1Token = tokenJson.readAddress(".transactions[0].contractAddress");

    // Get L1 bridge address
    string memory bridgeFile = "broadcast/multi/Deploy.s.sol-latest/run.json";
    string memory bridgeJson = vm.readFile(bridgeFile);

    address l1Bridge = bridgeJson.readAddress(".deployments[1].transactions[1].contractAddress");

    setFallbackToDefaultRpcUrls(false);

    vm.createSelectFork(getChain("avalanche_fuji").rpcUrl);

    IL1ERC20Bridge bridge = IL1ERC20Bridge(address(l1Bridge));
    IERC20Mint erc20 = IERC20Mint(address(deployedL1Token));

    // Mint some L1 token
    vm.broadcast();
    erc20.mint(msg.sender, 100_000);

    // Approve L1 token to be sent to the bridge
    vm.broadcast();
    erc20.approve(address(bridge), 100_000);

    // uint256 cost = bridge.quoteDeliveryCost(wormholePolygonId);
    // Deposit minted L1 token into the bridge and mint send a token to L2
    IWormholeRelayer WORMHOLE_RELAYER = IWormholeRelayer(wormholeCoreFuji);
    (uint256 cost,) = WORMHOLE_RELAYER.quoteEVMDeliveryPrice(5, 0, 500_000);

    bytes memory mintCalldata = abi.encode(msg.sender, 100_000);
    vm.broadcast();
    WORMHOLE_RELAYER.sendPayloadToEvm{value: cost}(
      5,
      0xc3e64Db48A4629cca7441f528Af1Ab9B66E9063a,
      mintCalldata,
      0, // no receiver value needed since we're just passing a message
      500_000
    );

    // bridge.deposit{value: cost}(msg.sender, 100_000);
  }
}
