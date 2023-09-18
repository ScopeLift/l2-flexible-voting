// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {WormholeL2VoteAggregator} from "src/WormholeL2VoteAggregator.sol";

contract L2VoteAggregatorHarness is WormholeL2VoteAggregator {
  constructor(
    address _votingToken,
    address _relayer,
    address _governorMetadata,
    address _l1BlockAddress,
    uint16 _sourceChain,
    uint16 _targetChain
  )
    WormholeL2VoteAggregator(
      _votingToken,
      _relayer,
      _governorMetadata,
      _l1BlockAddress,
      _sourceChain,
      _targetChain
    )
  {}

  function createProposalVote(uint256 proposalId, uint128 against, uint128 inFavor, uint128 abstain)
    public
  {
    proposalVotes[proposalId] = ProposalVote(against, inFavor, abstain);
  }
}
