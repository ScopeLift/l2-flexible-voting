// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {L2CountingFractional} from "src/L2CountingFractional.sol";

contract L2CountingFractionalHarness is L2CountingFractional {
  function exposed_countVote(
    uint256 proposalId,
    address account,
    uint8 support,
    uint256 totalWeight,
    bytes memory voteData
  ) public {
    return _countVote(proposalId, account, support, totalWeight, voteData);
  }

  function exposed_countVoteNominal(
    uint256 proposalId,
    address account,
    uint128 totalWeight,
    uint8 support
  ) public {
    return _countVoteNominal(proposalId, account, totalWeight, support);
  }

  function exposed_countVoteFractional(
    uint256 proposalId,
    address account,
    uint128 totalWeight,
    bytes memory voteData
  ) public {
    return _countVoteFractional(proposalId, account, totalWeight, voteData);
  }

  function exposed_decodePackedVotes(bytes memory voteData) public pure returns (uint128 againstVotes, uint128 forVotes, uint128 abstainVotes) {
		  return _decodePackedVotes(voteData);
  }

  function workaround_createProposalVote(
    uint256 proposalId,
    uint128 againstVotes,
    uint128 forVotes,
    uint128 abstainVotes
  ) public returns (ProposalVote memory) {
    _proposalVotes[proposalId] = ProposalVote(againstVotes, forVotes, abstainVotes);
    return _proposalVotes[proposalId];
  }

  function workaround_createProposalVoterWeightCast(
    uint256 proposalId,
    address account,
    uint128 weight
  ) public {
    _proposalVotersWeightCast[proposalId][account] = weight;
  }
}
