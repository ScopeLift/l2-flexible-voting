// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "openzeppelin/interfaces/IERC20.sol";

interface IERC20Mint is IERC20 {

  function mint(address account, uint256 amount) external;
}

interface IERC20Receive is IERC20Mint {

  function registerApplicationContracts(uint16 chainId, bytes32 applicationAddr) external;
}
