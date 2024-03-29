// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {L2VoteAggregator} from "src/L2VoteAggregator.sol";
import {WormholeL2VoteAggregator} from "src/WormholeL2VoteAggregator.sol";

contract WormholeL2VoteAggregatorCalldataCompressor is WormholeL2VoteAggregator {
  /// @dev Thrown when calldata is invalid for the provided function Id.
  error InvalidCalldata();

  /// @dev Thrown when calldata provides a function Id that does not exist.
  error FunctionDoesNotExist();

  /// @dev Thrown when a function is not supported.
  error UnsupportedFunction();

  /// @notice The internal proposal ID which is used by calldata optimized cast methods.
  uint16 internal nextInternalProposalId = 1;

  /// @notice The ID of the proposal mapped to an internal proposal ID.
  mapping(uint256 governorProposalId => uint16) public optimizedProposalIds;

  /// @param _votingToken The address of the L2 token used for voting.
  /// @param _relayer The address of the Wormhole relayer contract.
  /// state.
  /// @param _l1BlockAddress The address of the contract used to fetch the L1 block number.
  /// @param _sourceChain The Wormhole chain Id of the source chain when sending messages.
  /// @param _targetChain The Wormhole chain Id of the target chain when sending messages.
  constructor(
    address _votingToken,
    address _relayer,
    address _l1BlockAddress,
    uint16 _sourceChain,
    uint16 _targetChain,
    address _owner,
    uint32 _castWindow
  )
    WormholeL2VoteAggregator(
      _votingToken,
      _relayer,
      _l1BlockAddress,
      _sourceChain,
      _targetChain,
      _owner,
      _castWindow
    )
  {}

  /// @dev if we remove this function solc will give a missing-receive-ether warning because we have
  /// a payable fallback function. We cannot change the fallback function to a receive function
  /// because receive does not have access to msg.data. In order to prevent a missing-receive-ether
  /// warning we add a receive function and revert.
  receive() external payable {
    revert UnsupportedFunction();
  }

  /// @notice Casts a vote on L2 using a calldata optimized signature. Each cast vote method has a
  /// different Id documented below.
  ///
  /// 1 corresponds to `castVote`
  /// 2 corresponds to `castVoteWithReason`
  /// 3 corresponds to `castVoteBySig`
  fallback() external payable {
    uint8 funcId = uint8(bytes1(msg.data[0:1]));
    if (funcId == 1) _castVote(msg.data);
    else if (funcId == 2) _castVoteWithReason(msg.data);
    else if (funcId == 3) _castVoteBySig(msg.data);
    else revert FunctionDoesNotExist();
  }

  /// @dev Wrap the default `castVote` method in a method that optimizes the calldata.
  /// @param _msgData Optimized calldata for the `castVote` method. We restrict proposalId to a
  /// `uint16` rather than the default `uint256`.
  ///
  /// bytes 0-1: method Id
  /// bytes 1-3: proposal Id as a uint16
  /// bytes 3-4: voters support value as a uint8
  function _castVote(bytes calldata _msgData) internal {
    if (_msgData.length != 4) revert InvalidCalldata();
    uint16 proposalId = uint16(bytes2(_msgData[1:3])); // Supports max Id of 65,535
    uint8 support = uint8(bytes1(_msgData[3:4]));
    castVote(proposalId, L2VoteAggregator.VoteType(support));
  }

  /// @dev Wrap the default `castVoteWithReason` method in a method that optimizes the calldata.
  /// @param _msgData Optimized calldata for the `castVoteWithReason` method. We restrict proposalId
  /// to a `uint16` rather than the default `uint256`.
  ///
  /// bytes 0-1: method Id
  /// bytes 1-3: proposal Id as a uint16
  /// bytes 3-4: voters support value as a uint8
  /// bytes 4+: reason string
  function _castVoteWithReason(bytes calldata _msgData) internal {
    if (_msgData.length < 4) revert InvalidCalldata();
    uint16 proposalId = uint16(bytes2(_msgData[1:3]));
    uint8 support = uint8(bytes1(_msgData[3:4]));
    string calldata reason = string(_msgData[4:]);
    castVoteWithReason(proposalId, L2VoteAggregator.VoteType(support), reason);
  }

  /// @dev Wrap the default `castVoteBySig` method in a method that optimizes the calldata.
  /// @param _msgData Optimized calldata for the `castVoteBySig` method. We restrict proposalId to a
  /// `uint16` rather than the default `uint256`.
  ///
  /// bytes 0-1: method Id
  /// bytes 1-3: proposal Id as a uint16
  /// bytes 3-4: voters support value as a uint8
  /// bytes 4-5: the v value of the signature
  /// bytes 5-37: the r value of the signature
  /// bytes 37-69: the s value of the signature
  function _castVoteBySig(bytes calldata _msgData) internal {
    if (_msgData.length != 69) revert InvalidCalldata();
    uint16 proposalId = uint16(bytes2(_msgData[1:3]));
    uint8 support = uint8(bytes1(_msgData[3:4]));
    uint8 v = uint8(bytes1(_msgData[4:5]));
    bytes32 r = bytes32(_msgData[5:37]);
    bytes32 s = bytes32(_msgData[37:69]);
    castVoteBySig(proposalId, L2VoteAggregator.VoteType(support), v, r, s);
  }

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
