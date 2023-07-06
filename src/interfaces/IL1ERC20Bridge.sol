// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IL1ERC20Bridge {
  function deposit(address account, uint256 amount) external returns (uint16);
}
