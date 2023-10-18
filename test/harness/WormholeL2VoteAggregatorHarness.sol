// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {L2VoteAggregator} from "src/L2VoteAggregator.sol";
import {WormholeL2VoteAggregator} from "src/WormholeL2VoteAggregator.sol";
import {GovernorMetadataMockBase} from "test/mock/GovernorMetadataMock.sol";

contract WormholeL2VoteAggregatorHarness is WormholeL2VoteAggregator, GovernorMetadataMockBase {
  constructor(
    address _votingToken,
    address _relayer,
    address _l1BlockAddress,
    uint16 _sourceChain,
    uint16 _targetChain
  )
    WormholeL2VoteAggregator(
      _votingToken,
      _relayer,
      _l1BlockAddress,
      _sourceChain,
      _targetChain,
	  msg.sender
    )
  {}

  function createProposalVote(uint256 _proposalId, uint128 _against, uint128 _for, uint128 _abstain)
    public
  {
    proposalVotes[_proposalId] = ProposalVote(_against, _for, _abstain);
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
