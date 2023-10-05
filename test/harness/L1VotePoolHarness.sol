// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {L1VotePool} from "src/L1VotePool.sol";

contract L1VotePoolHarness is L1VotePool {
  constructor(address _governor) L1VotePool(_governor) {}

  // This is also not working
  function exposed_castVote(uint256 proposalId, ProposalVote memory vote) public {
    _castVote(proposalId, vote);
  }
}
