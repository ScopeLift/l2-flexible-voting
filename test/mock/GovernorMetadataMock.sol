// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {WormholeL2GovernorMetadata} from "src/WormholeL2GovernorMetadata.sol";
import {WormholeL2GovernorMetadataOptimized} from
  "src/optimized/WormholeL2GovernorMetadataOptimized.sol";
import {L2GovernorMetadata} from "src/L2GovernorMetadata.sol";

abstract contract GovernorMetadataMockBase is L2GovernorMetadata {
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

  function createProposal(uint256 proposalId, uint256 voteStart, uint256 voteEnd, bool isCanceled)
    public
    returns (Proposal memory)
  {
    Proposal memory proposal =
      Proposal({voteStart: voteStart, voteEnd: voteEnd, isCanceled: isCanceled});
    _proposals[proposalId] = proposal;
    return proposal;
  }
}

contract GovernorMetadataMock is GovernorMetadataMockBase, WormholeL2GovernorMetadata {
  constructor(address _core) WormholeL2GovernorMetadata(_core, msg.sender, address(0x1b), 1200) {
    _proposals[1] =
      Proposal({voteStart: block.number, voteEnd: block.number + 3000, isCanceled: false});
  }
}

contract GovernorMetadataOptimizedMock is
  GovernorMetadataMockBase,
  WormholeL2GovernorMetadataOptimized
{
  constructor(address _core)
    WormholeL2GovernorMetadataOptimized(_core, msg.sender, address(0x1b), 1200)
  {}

  function _addProposal(uint256 proposalId, uint256 voteStart, uint256 voteEnd, bool isCanceled)
    internal
    virtual
    override(L2GovernorMetadata, WormholeL2GovernorMetadataOptimized)
  {
    WormholeL2GovernorMetadataOptimized._addProposal(proposalId, voteStart, voteEnd, isCanceled);
  }
}
