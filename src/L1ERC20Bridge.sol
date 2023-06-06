// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// L1 transfer
// https://github.com/wormhole-foundation/wormhole/blob/main/ethereum/contracts/bridge/Bridge.sol#L191
// 
// L2 Process
// https://github.com/wormhole-foundation/wormhole/blob/main/ethereum/contracts/bridge/Bridge.sol#L431
//
// Whether we trust the untrusted relayer https://book.wormhole.com/technical/evm/relayer.html

// Test from optimism Goerli to optimism goerli

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";


contract L1ERC20Bridge {
  IERC20 public immutable L1_TOKEN;
  address public immutable L2_TOKEN_ADDRESS;
  // trusted relayer contract on this chain
  IWormholeRelayer immutable relayer;

  constructor(address l1TokenAddress, address l2TokenAddress) {
		  L1_TOKEN = IERC20(l1TokenAddress);
		  L2_TOKEN_ADDRESS = l2TokenAddress;
  }

  function deposit(uint256 amount) external {
    // TODO keep track of deposit
    L1_TOKEN.transferFrom(msg.sender, address(this), amount);
	// mint on L2
	// 1. encode packed mint args
	// 2. send message to relayer contract
	// 3. On L2 token receive and mint
	_l2Mint(msg.sender, amount);
  }

  // Can't really test because relayers not released yet
  function _l2Mint(address account, uint256 amount) {
    bytes memory mintCalldata = abi.encode(account, amount);

  }
}
