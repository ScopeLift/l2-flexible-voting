// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {L2GovernorMetadata} from "src/L2GovernorMetadata.sol";
import {WormholeL2GovernorMetadata} from "src/WormholeL2GovernorMetadata.sol";

contract WormholeL2GovernorMetadataOptimized is WormholeL2GovernorMetadata {
  /// @notice The internal proposal ID which is used by calldata optimized cast methods.
  uint16 internal nextInternalProposalId = 1;

  /// @notice The ID of the proposal mapped to an internal proposal ID.
  mapping(uint256 governorProposalId => uint16) public optimizedProposalIds;

  constructor(address _relayer, address _owner) WormholeL2GovernorMetadata(_relayer, _owner) {}

  /// @inheritdoc L2GovernorMetadata
  function _addProposal(uint256 proposalId, uint256 voteStart, uint256 voteEnd, bool isCanceled)
    internal
    virtual
    override
  {
    super._addProposal(proposalId, voteStart, voteEnd, isCanceled);
    uint16 internalId = optimizedProposalIds[proposalId];
    if (internalId == 0) {
      optimizedProposalIds[proposalId] = nextInternalProposalId;
      ++nextInternalProposalId;
    }
  }
}
