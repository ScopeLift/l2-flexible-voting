// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {WormholeBase} from "src/WormholeBase.sol";

abstract contract WormholeSender is WormholeBase {
  /// @notice The chain id that is receiving the messages.
  uint16 public immutable TARGET_CHAIN;

  /// @notice The chain id where refunds will be sent.
  uint16 public immutable REFUND_CHAIN;

  /// @notice The gas limit for cross chain transactions.
  uint256 public gasLimit = 200_000;

  /// @notice Emitted when the gas limit has been updated
  /// @param oldValue The old gas limit value.
  /// @param newValue The new gas limit value.
  /// @param caller The address changing the gas limit.
  event GasLimitUpdate(uint256 oldValue, uint256 newValue, address caller);

  /// @param _refundChain The chain id of the chain sending the messages.
  /// @param _targetChain The chain id of the chain receiving the messages.
  constructor(uint16 _refundChain, uint16 _targetChain) {
    REFUND_CHAIN = _refundChain;
    TARGET_CHAIN = _targetChain;
  }

  /// @param targetChain The chain id of the chain receiving the messages.
  function quoteDeliveryCost(uint16 targetChain) public view virtual returns (uint256 cost) {
    (cost,) = WORMHOLE_RELAYER.quoteEVMDeliveryPrice(targetChain, 0, gasLimit);
  }

  /// @param _gasLimit The new gas limit value which is used to estimate the delivery cost for
  /// sending messages cross chain.
  function updateGasLimit(uint256 _gasLimit) public onlyOwner {
    emit GasLimitUpdate(gasLimit, _gasLimit, msg.sender);
    gasLimit = _gasLimit;
  }
}
