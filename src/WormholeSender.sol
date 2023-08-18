// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {IWormholeRelayer} from "wormhole/interfaces/relayer/IWormholeRelayer.sol";
import {WormholeBase} from "src/WormholeBase.sol";

abstract contract WormholeSender is WormholeBase {
  /// @notice The chain id that is receiving the messages.
  uint16 public immutable TARGET_CHAIN;

  /// @notice The chain id that is sending the messages.
  uint16 public immutable SOURCE_CHAIN;

  /// @notice The gas limit for cross chain transactions.
  uint256 constant GAS_LIMIT = 500_000;

  /// @param _targetChain The chain id of the chain receiving the messages.
  /// @param _sourceChain The chain id of the chain sending the messages.
  constructor(uint16 _sourceChain, uint16 _targetChain) {
    SOURCE_CHAIN = _sourceChain;
    TARGET_CHAIN = _targetChain;
  }

  /// @param targetChain The chain id of the chain receiving the messages.
  function quoteDeliveryCost(uint16 targetChain) public virtual returns (uint256 cost) {
    (cost,) = WORMHOLE_RELAYER.quoteEVMDeliveryPrice(targetChain, 0, GAS_LIMIT);
  }
}
