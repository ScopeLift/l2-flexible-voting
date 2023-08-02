// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IL1ERC20Bridge {
  function deposit(address account, uint256 amount) external payable returns (uint16);
  function quoteDeliveryCost(uint16 targetChain) external returns (uint256);
  function initialize(address _l1Token) external;
}
