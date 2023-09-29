// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {WormholeL2ERC20} from "src/WormholeL2ERC20.sol";

contract WormholeL2ERC20Router {
  WormholeL2ERC20 public immutable L2_ERC20;

  /// @dev Thrown when a function is not supported.
  error UnsupportedFunction();

  constructor(address _l2Erc20) {
    L2_ERC20 = WormholeL2ERC20(_l2Erc20);
  }
    /// @dev if we remove this function solc will give a missing-receive-ether warning because we have
  /// a payable fallback function. We cannot change the fallback function to a receive function
  /// because receive does not have access to msg.data. In order to prevent a missing-receive-ether
  /// warning we add a receive function and revert.
  receive() external payable {
    revert UnsupportedFunction();
  }

  function _l1Unlock(address account, uint96 amount) internal {
    L2_ERC20.l1Unlock(account, amount);
  }

  fallback() external payable {
    uint96 amount = uint96(bytes12(msg.data[1:13]));
    _l1Unlock(msg.sender, amount);
  }
}
