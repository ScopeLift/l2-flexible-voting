// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {IGovernor} from "openzeppelin/governance/Governor.sol";
import {IWormhole} from "wormhole/interfaces/IWormhole.sol";
import {WormholeSender} from "src/WormholeSender.sol";

/// @notice Handles sending proposal metadata such as proposal id, start date and end date from L1
/// to L2.
contract L1GovernorMetadataBridge is WormholeSender {
  /// @notice The governor where proposals are fetched and bridged.
  IGovernor public immutable GOVERNOR;

  /// @notice The L2 governor metadata address where the message is sent on L2.
  address public L2_GOVERNOR_ADDRESS;

  /// @notice Indicates whether the contract has been initialized with the L2 governor metadata. It
  /// can only be called once.
  bool public INITIALIZED = false;

  /// @notice The proposal id is an invalid proposal id.
  error InvalidProposalId();

  /// @dev Contract is already initialized with an L2 token.
  error AlreadyInitialized();

  /// @param _governor The address of the L1 governor contract.
  /// @param _relayer The address of the L1 Wormhole relayer contract.
  constructor(address _governor, address _relayer, uint16 _sourceChain, uint16 _targetChain)
    WormholeSender(_relayer, _sourceChain, _targetChain)
  {
    GOVERNOR = IGovernor(_governor);
  }

  /// @param l2GovernorMetadata The address of the L2 governor metadata contract.
  function initialize(address l2GovernorMetadata) public {
    if (INITIALIZED) revert AlreadyInitialized();
    INITIALIZED = true;
    L2_GOVERNOR_ADDRESS = l2GovernorMetadata;
  }

  /// @notice Publishes a messages with the proposal id, start block and end block
  /// @param proposalId The id of the proposal to bridge.
  function bridge(uint256 proposalId) public payable returns (uint256) {
    uint256 voteStart = GOVERNOR.proposalSnapshot(proposalId);
    if (voteStart == 0) revert InvalidProposalId();
    uint256 voteEnd = GOVERNOR.proposalDeadline(proposalId);

    bytes memory proposalCalldata = abi.encode(proposalId, voteStart, voteEnd);
    uint256 cost = quoteDeliveryCost(TARGET_CHAIN);
    return WORMHOLE_RELAYER.sendPayloadToEvm{value: cost}(
      TARGET_CHAIN,
      L2_GOVERNOR_ADDRESS,
      proposalCalldata,
      0, // no receiver value needed since we're just passing a message
      GAS_LIMIT,
      SOURCE_CHAIN,
      msg.sender
    );
  }
}
