// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {WormholeL2GovernorMetadataOptimized} from
  "src/optimized/WormholeL2GovernorMetadataOptimized.sol";

contract WormholeL2GovernorMetadataOptimizedHarness is WormholeL2GovernorMetadataOptimized {
  constructor(address _core, address _owner, address _l1BlockAddress)
    WormholeL2GovernorMetadataOptimized(_core, _owner, _l1BlockAddress, 1200)
  {}

  function exposed_addProposal(
    uint256 proposalId,
    uint256 voteStart,
    uint256 voteEnd,
    bool isCanceled
  ) external {
    _addProposal(proposalId, voteStart, voteEnd, isCanceled);
  }
}
