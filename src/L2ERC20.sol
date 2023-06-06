// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Inherit the ERC20Votes
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

contract L2ERC20 is ERC20Votes {
  // TODO this can only be called by the wormhole relayer.
  function mint(address account, uint256 amount) external public {
		  _mint(account, amount);
  }
}

