// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {L2GovernorMetadata} from "src/L2GovernorMetadata.sol";

contract GovernorMetadataMock is L2GovernorMetadata {
  constructor(address _core) L2GovernorMetadata(_core) {
    _proposals[1] = Proposal({voteStart: block.number, voteEnd: block.number + 3000});
  }

  function getProposal(uint256 proposalId) public view override returns (Proposal memory) {
    return _proposals[1];
  }
}
