// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {SafeCast} from "openzeppelin/utils/math/SafeCast.sol";
import {IL1Block} from "src/interfaces/IL1Block.sol";

/// @dev Optimism has an L1 block contract that shares the same functions as this one. Since, we are
/// testing on testnets without an L1 block contract we need to create our own implementation for
/// testing purposes. We may also need this implementation for Arbitrum as well since they do not
/// have an L1 block contract.
///
/// Arbitrum L1 block reference: https://developer.arbitrum.io/time
/// Optimism L1 block reference:
/// https://github.com/ethereum-optimism/optimism/blob/65ec61dde94ffa93342728d324fecf474d228e1f/packages/contracts-bedrock/contracts/L2/L1Block.sol
contract L1Block is IL1Block {
  // We could keep as uint64
  // https://github.com/sherlock-audit/2023-01-optimism-judging/issues/278
  function number() external view returns (uint64) {
    return SafeCast.toUint64(block.number);
  }

  function timestamp() external view returns (uint64) {
    return SafeCast.toUint64(block.timestamp);
  }

  function basefee() external view returns (uint256) {
    return block.basefee;
  }

  function hash() external view returns (bytes32) {
    return blockhash(block.number);
  }
}
