// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {WormholeBase} from "src/WormholeBase.sol";

abstract contract WormholeSender is WormholeBase {
  /// @notice The chain id that is receiving the messages.
  uint16 public immutable TARGET_CHAIN;

  /// @notice The chain id where refunds will be sent.
  uint16 public immutable REFUND_CHAIN;

  /// @notice The gas limit for cross chain transactions.
  uint256 constant GAS_LIMIT = 500_000;

  /// @param _refundChain The chain id of the chain sending the messages.
  /// @param _targetChain The chain id of the chain receiving the messages.
  constructor(uint16 _refundChain, uint16 _targetChain) {
    REFUND_CHAIN = _refundChain;
    TARGET_CHAIN = _targetChain;
  }

  /// @param targetChain The chain id of the chain receiving the messages.
  function quoteDeliveryCost(uint16 targetChain) public view virtual returns (uint256 cost) {
    (cost,) = WORMHOLE_RELAYER.quoteEVMDeliveryPrice(targetChain, 0, GAS_LIMIT);
  }
}
