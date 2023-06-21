
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {Script, stdJson} from "forge-std/Script.sol";
import {IERC20} from "openzeppelin/interfaces/IERC20.sol";
import {L1ERC20Bridge} from "src/L1ERC20Bridge.sol";
import {console2} from "forge-std/console2.sol";
import {IWormholeRelayer, VaaKey} from "wormhole/interfaces/relayer/IWormholeRelayer.sol";

interface IERC20Mint is IERC20 {
  function mint(address account, uint256 amount) external;
}

interface IL1ERC20Bridge {
  function L1_TOKEN() external returns (IERC20);
  function deposit(address account, uint256 amount, address refundAccount, uint16 refundChain)
    external
    returns (uint16);
}

contract MintOnL2 is Script {
  using stdJson for string;

  function run() public {
    // Deploy the bridge
    // then deploy the erc20Votes token
    //
    // Avalanche is mimicking the L1
    string memory tokenFile = "broadcast/DeployFakeERC20.s.sol/43113/run-latest.json";
    string memory tokenJson = vm.readFile(tokenFile);
    string memory bridgeFile = "broadcast/multi/Deploy.s.sol-latest/run.json";
    string memory bridgeJson = vm.readFile(bridgeFile);

    address deployedL1Token = tokenJson.readAddress(".transactions[0].contractAddress");
    // mumbai
    // address l1Bridge = 0xBaA85b5C4c74f53c46872acfF2750f512bcBEC43;
    address l1Bridge = bridgeJson.readAddress(".deployments[1].transactions[0].contractAddress");
	// register l1 address on L2 token
    // address l2Address = 0x274f91013435f3fe900aa980021f8241d51d7fd8;
    uint16 targetChain = 5;

       // Wormhole id for mumbai
    setFallbackToDefaultRpcUrls(false);
    vm.createSelectFork(getChain("avalanche_fuji").rpcUrl);

    IL1ERC20Bridge bridge = IL1ERC20Bridge(address(l1Bridge));
	IERC20Mint erc20 = IERC20Mint(address(deployedL1Token));

    vm.broadcast();
    erc20.mint(msg.sender, 100_000);

    // console2.logAddress(address(bridge.L1_TOKEN()));
    console2.logUint(erc20.balanceOf(msg.sender));

    vm.broadcast();
    erc20.approve(address(bridge), 100_000_000);

	IWormholeRelayer relayer = IWormholeRelayer(0xA3cF45939bD6260bcFe3D66bc73d60f19e49a8BB);
    bytes memory mintCalldata = abi.encodePacked(msg.sender, uint256(100_000));
    (uint256 deliveryCost,) = relayer.quoteEVMDeliveryPrice(5, 0, 500_000);

    vm.broadcast();
    relayer.sendPayloadToEvm{value: deliveryCost}(
      5, 0x709f84918fc0E2F96F4F67813377e7b27aCB63ee, mintCalldata, 0, 500_000
    );
  }
}
