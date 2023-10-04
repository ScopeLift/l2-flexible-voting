// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {WormholeL2GovernorMetadata} from "src/WormholeL2GovernorMetadata.sol";

contract WormholeL2GovernorMetadataOptimized is WormholeL2GovernorMetadata {
  /// @notice
  uint16 internal _proposalId = 1;

  /// @notice The id of the proposal mapped to the proposal metadata.
  mapping(uint256 governorProposalId => uint16) public optimizedProposalIds;

  constructor(address _relayer, address _owner) WormholeL2GovernorMetadata(_relayer, _owner) {}

  function _addProposal(uint256 proposalId, uint256 voteStart, uint256 voteEnd, bool isCanceled)
    internal
    virtual
    override
  {
    super._addProposal(proposalId, voteStart, voteEnd, isCanceled);
    uint16 internalId = optimizedProposalIds[proposalId];
    if (internalId == 0) {
      optimizedProposalIds[proposalId] = _proposalId;
      ++_proposalId;
    }
  }
}
