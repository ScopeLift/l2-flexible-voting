// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {ERC20Votes} from "openzeppelin/token/ERC20/extensions/ERC20Votes.sol";
import {ERC20Permit} from "openzeppelin/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {IERC20Mint} from "src/interfaces/IERC20Mint.sol";

contract FakeERC20 is ERC20Votes, IERC20Mint {
  constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) ERC20Permit(_name) {}

  function mint(address account, uint256 amount) public {
    _mint(account, amount);
  }
}


