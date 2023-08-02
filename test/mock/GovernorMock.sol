// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20Votes} from "openzeppelin/token/ERC20/extensions/ERC20Votes.sol";
import {GovernorVoteMocks} from "openzeppelin/mocks/governance/GovernorVoteMock.sol";
import {GovernorVotes} from "openzeppelin/governance/extensions/GovernorVotes.sol";
import {Governor} from "openzeppelin/governance/Governor.sol";
import {GovernorSettings} from "openzeppelin/governance/extensions/GovernorSettings.sol";
import {GovernorCountingFractional} from "flexible-voting/src/GovernorCountingFractional.sol";
import {Governor as FlexGovernor} from "openzeppelin-flexible-voting/governance/Governor.sol";
import {
  GovernorVotesComp,
  ERC20VotesComp
} from "openzeppelin-flexible-voting/governance/extensions/GovernorVotesComp.sol";
import {IGovernor} from "openzeppelin-flexible-voting/governance/IGovernor.sol";

contract GovernorMock is GovernorVoteMocks {
  constructor(string memory _name, ERC20Votes _token) Governor(_name) GovernorVotes(_token) {}
}

contract GovernorFlexibleVotingMock is GovernorCountingFractional, GovernorVotesComp {
  constructor(string memory _name, ERC20VotesComp _token)
    FlexGovernor(_name)
    GovernorVotesComp(_token)
  {}

  function quorum(uint256) public pure override returns (uint256) {
    return 0;
  }

  function votingDelay() public pure override returns (uint256) {
    return 4;
  }

  function votingPeriod() public pure override returns (uint256) {
    return 16;
  }

  /// @dev We override this function to resolve ambiguity between inherited contracts.
  function castVoteWithReasonAndParamsBySig(
    uint256 proposalId,
    uint8 support,
    string calldata reason,
    bytes memory params,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) public override(FlexGovernor, GovernorCountingFractional) returns (uint256) {
    return GovernorCountingFractional.castVoteWithReasonAndParamsBySig(
      proposalId, support, reason, params, v, r, s
    );
  }
}
