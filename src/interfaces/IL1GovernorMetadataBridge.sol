// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IL1GovernorMetadataBridge {
  function bridgeProposalMetadata(uint256 proposalId) external payable returns (uint16);
  function quoteDeliveryCost(uint16 targetChain) external returns (uint256);
}
