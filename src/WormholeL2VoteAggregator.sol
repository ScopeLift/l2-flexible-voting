// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {L2GovernorMetadata} from "src/WormholeL2GovernorMetadata.sol";
import {L2VoteAggregator} from "src/L2VoteAggregator.sol";
import {WormholeSender} from "src/WormholeSender.sol";
import {WormholeBase} from "src/WormholeBase.sol";

/// @notice A contract to collect votes on L2 to be bridged to L1.
contract WormholeL2VoteAggregator is WormholeSender, L2VoteAggregator {
  /// @param _votingToken The token used to vote on proposals.
  /// @param _relayer The Wormhole generic relayer contract.
  /// @param _governorMetadata The `GovernorMetadata` contract that provides proposal information.
  /// @param _l1BlockAddress The address of the L1Block contract.
  /// @param _sourceChain The chain sending the votes.
  /// @param _targetChain The target chain to bridge the votes to.
  constructor(
    address _votingToken,
    address _relayer,
    address _governorMetadata,
    address _l1BlockAddress,
    uint16 _sourceChain,
    uint16 _targetChain
  )
    L2VoteAggregator(_votingToken, _governorMetadata, _l1BlockAddress)
    WormholeBase(_relayer)
    WormholeSender(_sourceChain, _targetChain)
  {}

  /// @notice Wormhole-specific implementation of `_bridgeVote`.
  /// @param proposalCalldata The calldata for the proposal.
  function _bridgeVote(bytes memory proposalCalldata) internal override {
    uint256 cost = quoteDeliveryCost(TARGET_CHAIN);
    WORMHOLE_RELAYER.sendPayloadToEvm{value: cost}(
      TARGET_CHAIN,
      L1_BRIDGE_ADDRESS,
      proposalCalldata,
      0, // no receiver value needed since we're just passing a message
      GAS_LIMIT,
      REFUND_CHAIN,
      msg.sender
    );
  }
}
