// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {IWormholeRelayer} from "wormhole/interfaces/relayer/IWormholeRelayer.sol";

contract WormholeSender {
  /// @notice The wormhole relayer used to trustlessly send messages.
  IWormholeRelayer internal immutable WORMHOLE_RELAYER;

  /// @notice The chain id that is receiving the messages.
  uint16 public immutable TARGET_CHAIN;

  /// @notice The chain id that is sending the messages.
  uint16 public immutable SOURCE_CHAIN;

  /// @notice The gas limit for cross chain transactions.
  uint256 constant GAS_LIMIT = 500_000;

  /// @param _relayer The address of the source chain Wormhole relayer contract.
  /// @param _targetChain The chain id of the chain receiving the messages.
  /// @param _sourceChain The chain id of the chain sending the messages.
  constructor(address _relayer, uint16 _sourceChain, uint16 _targetChain) {
    WORMHOLE_RELAYER = IWormholeRelayer(_relayer);
    SOURCE_CHAIN = _sourceChain;
    TARGET_CHAIN = _targetChain;
  }

  /// @param targetChain The chain id of the chain receiving the messages.
  function quoteDeliveryCost(uint16 targetChain) public virtual returns (uint256 cost) {
    (cost,) = WORMHOLE_RELAYER.quoteEVMDeliveryPrice(targetChain, 0, GAS_LIMIT);
  }
}
