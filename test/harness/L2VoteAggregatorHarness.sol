// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {L2VoteAggregator} from "src/L2VoteAggregator.sol";
import {WormholeL2VoteAggregator} from "src/WormholeL2VoteAggregator.sol";

contract L2VoteAggregatorHarness is L2VoteAggregator {
  constructor(address _votingToken, address _governorMetadata, address _l1BlockAddress)
    L2VoteAggregator(_votingToken, _governorMetadata, _l1BlockAddress)
  {}

  function _bridgeVote(bytes memory) internal override {}

  function exposed_castVote(
    uint256 proposalId,
    address voter,
    VoteType support,
    string memory reason
  ) public returns (uint256) {
    return _castVote(proposalId, voter, support, reason);
  }

  function exposed_domainSeparatorV4() public view returns (bytes32) {
    return _domainSeparatorV4();
  }
}