// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20Votes} from "openzeppelin/token/ERC20/extensions/ERC20Votes.sol";
import {GovernorVoteMocks} from "openzeppelin/mocks/governance/GovernorVoteMock.sol";
import {GovernorVotes} from "openzeppelin/governance/extensions/GovernorVotes.sol";
import {Governor} from "openzeppelin/governance/Governor.sol";

contract GovernorMock is GovernorVoteMocks {
  constructor(string memory _name, ERC20Votes _token) Governor(_name) GovernorVotes(_token) {}
}
