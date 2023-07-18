// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IL1GovernorMetadataBridge {
  function bridge(uint256 proposalId) external returns (uint16);
}
