// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20VotesComp} from "openzeppelin/token/ERC20/extensions/ERC20VotesComp.sol";

import {ERC20Permit} from "openzeppelin/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {IERC20Mint} from "src/interfaces/IERC20Mint.sol";

/// @notice An ERC20Votes token to help test the L2 voting system
contract ERC20VotesCompMock is ERC20VotesComp, IERC20Mint {
  constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) ERC20Permit(_name) {}

  /// @dev Mints tokens to an address to help test bridging and voting.
  /// @param account The address of where to mint the tokens.
  /// @param amount The amount of tokens to mint.
  function mint(address account, uint256 amount) public {
    _mint(account, amount);
    delegate(account);
  }
}
