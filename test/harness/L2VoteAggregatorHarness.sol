// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {L2VoteAggregator} from "src/L2VoteAggregator.sol";
import {WormholeL2VoteAggregator} from "src/WormholeL2VoteAggregator.sol";
import {GovernorMetadataMockBase, L2GovernorMetadata} from "test/mock/GovernorMetadataMock.sol";

contract L2VoteAggregatorHarness is L2VoteAggregator, GovernorMetadataMockBase {
  constructor(address _votingToken, address _l1BlockAddress)
    L2VoteAggregator(_votingToken)
    L2GovernorMetadata(_l1BlockAddress)
  {}

  function _bridgeVote(bytes memory) internal override {}

  function exposed_bridgeVote(bytes memory proposalCalldata) public {
    _bridgeVote(proposalCalldata);
  }

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
