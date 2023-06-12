// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {Script} from "forge-std/Script.sol";
import {IERC20} from "openzeppelin/interfaces/IERC20.sol";
import {L1ERC20Bridge} from "src/L1ERC20Bridge.sol";
import {console2} from "forge-std/console2.sol";

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
  function run() public {
    // Deploy the bridge
    // then deploy the erc20Votes token
    //
    // Avalanche is mimicking the L1
    address deployedL1Token = 0x630567C26340Da0700E6572E0FFa72e10e002B35;
    // mumbai
    // address l1Bridge = 0xBaA85b5C4c74f53c46872acfF2750f512bcBEC43;
    address l1Bridge = 0x9fd0B0551539a916Fb7B5aF7a2C55447CdAA9276;
	// register l1 address on L2 token
    // address l2Address = 0x274f91013435f3fe900aa980021f8241d51d7fd8;
    uint16 targetChain = 5;
	address callingAddress = 0xEAC5F0d4A9a45E1f9FdD0e7e2882e9f60E301156;

       // Wormhole id for mumbai
    setFallbackToDefaultRpcUrls(false);
    vm.createSelectFork(getChain("avalanche_fuji").rpcUrl);

    IL1ERC20Bridge bridge = IL1ERC20Bridge(address(l1Bridge));
	IERC20Mint erc20 = IERC20Mint(address(deployedL1Token));

    vm.broadcast();
    erc20.mint(callingAddress, 100_000);

    // console2.logAddress(address(bridge.L1_TOKEN()));
    console2.logUint(erc20.balanceOf(callingAddress));

    vm.broadcast();
    erc20.approve(address(bridge), 100_000_000);

    vm.broadcast();
    bridge.deposit(callingAddress, 100_000, callingAddress, targetChain);
  }
}
