// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

// interface is for contract defined at
// https://github.com/ethereum-optimism/optimism/blob/develop/packages/contracts-bedrock/contracts/L2/L1Block.sol
interface IL1Block {
  /// @notice The latest L1 block number known by the L2 system.
  function number() external view returns (uint64);

  /// @notice The latest L1 timestamp known by the L2 system.
  function timestamp() external view returns (uint64);

  /// @notice The latest L1 basefee.
  function basefee() external view returns (uint256);

  /// @notice The latest L1 blockhash.
  function hash() external view returns (bytes32);
}
