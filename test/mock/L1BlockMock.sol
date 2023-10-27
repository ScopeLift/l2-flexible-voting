// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IL1Block} from "src/interfaces/IL1Block.sol";
import {StdUtils} from "forge-std/Test.sol";

/// @dev For use in proposal related tests that need access to the L1Block only for the purpose of
/// calculating an L2 block to emit in the proposal created events, for the sake of compatibility
/// with existing frontend clients.
contract L1BlockMock is IL1Block, StdUtils {
  // An arbitrary, large, mainnet-block-like number for use with the mock L1 Block
  uint64 private NUMBER = 18_442_511;
  uint64 private TIMESTAMP = 0;
  uint256 private BASEFEE = 0;
  bytes32 private HASH = blockhash(NUMBER);

  function number() external view returns (uint64) {
    return NUMBER;
  }

  function timestamp() external view returns (uint64) {
    return TIMESTAMP;
  }

  function basefee() external view returns (uint256) {
    return BASEFEE;
  }

  function hash() external view returns (bytes32) {
    return HASH;
  }

  /// @dev For use in tests to ensure a fuzzed L1 block vote end conforms to the internal invariant
  /// requirements inside the L2GovernorMetadata
  function __boundL1VoteEnd(uint256 _l1VoteEnd) public view returns (uint256) {
    return bound(_l1VoteEnd, NUMBER + 3000, NUMBER + 2_628_000);
  }

  /// @dev Matches the implementation inside L2GovernorMetadata for the sake of test expectations
  function __expectedL2BlockForFutureBlock(uint256 _l1BlockNumber) external view returns (uint256) {
    require(
      _l1BlockNumber > NUMBER + 1200,
      "L1BlockMock: Bad test parameters, _l1BlockNumber must be greater than mock current block number"
    );

    uint256 _l1BlocksUntilEnd = _l1BlockNumber - NUMBER - 1200;
    return (_l1BlocksUntilEnd * 12) / 2;
  }
}
