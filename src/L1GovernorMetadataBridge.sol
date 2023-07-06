// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {IGovernor} from "openzeppelin/governance/Governor.sol";
import {IWormhole} from "wormhole/interfaces/IWormhole.sol";

/// @notice Handles sending proposal metadata such as proposal id, start date and end date from L1
/// to L2.
contract L1GovernorMetadataBridge {
  /// @notice The governor where proposals are fetched and bridged.
  IGovernor public immutable GOVERNOR;

  /// @notice The Wormhole core contract used to relay messages.
  IWormhole public coreBridge;

  /// @notice The L2 governor metadata address where the message is sent on L2.
  address public L2_GOVERNOR_ADDRESS;

  /// @notice Indicates whether the contract has been initialized with the L2 governor metadata. It
  /// can only be called once.
  bool public INITIALIZED = false;

  /// @notice A unique number used to send messages.
  uint32 public nonce;

  /// @notice The proposal id is an invalid proposal id.
  error InvalidProposalId();

  /// @param _governor The address of the L1 governor contract.
  /// @param _core The address of the L1 core wormhole contract.
  constructor(address _governor, address _core) {
    GOVERNOR = IGovernor(_governor);
    coreBridge = IWormhole(_core);
    nonce = 0;
  }

  /// @param l2GovernorMetadata The address of the L2 governor metadata contract.
  function initialize(address l2GovernorMetadata) public {
    if (!INITIALIZED) {
      INITIALIZED = true;
      L2_GOVERNOR_ADDRESS = l2GovernorMetadata;
    }
  }

  /// @notice Publishes a messages with the proposal id, start block and end block
  /// @param proposalId The id of the proposal to bridge.
  function bridge(uint256 proposalId) external payable returns (uint64 sequence) {
    uint256 voteStart = GOVERNOR.proposalSnapshot(proposalId);
    if (voteStart == 0) revert InvalidProposalId();
    uint256 voteEnd = GOVERNOR.proposalDeadline(proposalId);

    bytes memory proposalCalldata = abi.encodePacked(proposalId, voteStart, voteEnd);
    sequence = coreBridge.publishMessage(nonce, proposalCalldata, 1);
    nonce = nonce + 1;
    return sequence;
  }
}
