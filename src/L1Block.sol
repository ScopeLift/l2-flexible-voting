// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {SafeCast} from "openzeppelin/utils/math/SafeCast.sol";
import {IL1Block} from "src/interfaces/IL1Block.sol";

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
