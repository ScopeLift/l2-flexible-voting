// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {L2VoteAggregator} from "src/L2VoteAggregator.sol";
import {WormholeL2VoteAggregator} from "src/WormholeL2VoteAggregator.sol";

contract WormholeL2VoteAggregatorRouter {
  WormholeL2VoteAggregator public immutable L2_VOTE_AGGREGATOR;

  
  /// @dev Thrown when calldata is invalid for the provided function id.
  error InvalidCalldata();

    /// @dev Thrown when calldata provides a function ID that does not exist.
  error FunctionDoesNotExist();

    /// @dev Thrown when a function is not supported.
  error UnsupportedFunction();

  constructor(address _voteAggregator) {
    L2_VOTE_AGGREGATOR = WormholeL2VoteAggregator(_voteAggregator);
  }

    /// @dev if we remove this function solc will give a missing-receive-ether warning because we have
  /// a payable fallback function. We cannot change the fallback function to a receive function
  /// because receive does not have access to msg.data. In order to prevent a missing-receive-ether
  /// warning we add a receive function and revert.
  receive() external payable {
    revert UnsupportedFunction();
  }

  function _castVote(bytes calldata msgData) internal {
    if (msgData.length != 49) revert InvalidCalldata();
    uint16 proposalId = uint16(bytes2(msgData[1:3]));
    uint8 support = uint8(bytes1(msgData[3:4]));
    L2_VOTE_AGGREGATOR.castVote(proposalId, L2VoteAggregator.VoteType(support));
  }

  // proposalId
  // funcId
  // 1. castVote
  fallback() external payable {
    uint8 funcId = uint8(bytes1(msg.data[0:1]));
	if (funcId == 1) _castVote(msg.data);
	else revert FunctionDoesNotExist();
  }
}
