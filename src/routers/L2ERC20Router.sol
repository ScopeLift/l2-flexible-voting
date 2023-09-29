// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {WormholeL2ERC20} from "src/WormholeL2ERC20.sol";

contract WormholeL2ERC20Router {
  WormholeL2ERC20 public immutable L2_ERC20;

  constructor(address _l2Erc20) {
    L2_ERC20 = WormholeL2ERC20(_l2Erc20);
  }

  function _l1Unlock(address account, uint96 amount) internal payable {
    L2_ERC20.l1Unlock(account, amount);
  }

  fallback() external payable {
    amount = uint96(bytes12(msg.data[1:13]));
    _l1Unlock(msg.sender, amount);
  }
}
