// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {WormholeL2GovernorMetadata} from "src/WormholeL2GovernorMetadata.sol";

contract GovernorMetadataMock is WormholeL2GovernorMetadata {
  constructor(address _core) WormholeL2GovernorMetadata(_core) {
    _proposals[1] = Proposal({voteStart: block.number, voteEnd: block.number + 3000});
  }

  function getProposal(uint256) public view override returns (Proposal memory) {
    return _proposals[1];
  }
}
