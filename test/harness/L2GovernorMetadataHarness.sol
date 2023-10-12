// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {L2GovernorMetadata} from "src/L2GovernorMetadata.sol";
import {TestConstants} from "test/Constants.sol";

contract L2GovernorMetadataHarness is L2GovernorMetadata {
  function exposed_proposals(uint256 proposalId) public view returns (Proposal memory) {
    return _proposals[proposalId];
  }

  function exposed_addProposal(
    uint256 proposalId,
    uint256 voteStart,
    uint256 voteEnd,
    bool isCanceled
  ) public {
    _addProposal(proposalId, voteStart, voteEnd, isCanceled);
  }
}
