// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {WormholeL2GovernorMetadata} from "src/WormholeL2GovernorMetadata.sol";

contract GovernorMetadataMock is WormholeL2GovernorMetadata {
  constructor(address _core) WormholeL2GovernorMetadata(_core, msg.sender) {
    _proposals[1] =
      Proposal({voteStart: block.number, voteEnd: block.number + 3000, isCanceled: false});
  }

  function createProposal(uint256 proposalId, uint128 timeToProposalEnd)
    public
    returns (Proposal memory)
  {
    Proposal memory proposal = Proposal({
      voteStart: block.number,
      voteEnd: block.number + timeToProposalEnd,
      isCanceled: false
    });
    _proposals[proposalId] = proposal;
    return proposal;
  }

  function createProposal(uint256 proposalId, uint128 timeToProposalEnd, bool isCanceled)
    public
    returns (Proposal memory)
  {
    Proposal memory proposal = Proposal({
      voteStart: block.number,
      voteEnd: block.number + timeToProposalEnd,
      isCanceled: isCanceled
    });
    _proposals[proposalId] = proposal;
    return proposal;
  }
}
