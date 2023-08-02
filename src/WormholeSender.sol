// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {IWormholeRelayer} from "wormhole/interfaces/relayer/IWormholeRelayer.sol";

contract WormholeSender {
  /// @notice The wormhole relayer used to trustlessly send messages.
  IWormholeRelayer internal immutable WORMHOLE_RELAYER;
  uint16 public immutable TARGET_CHAIN;
  uint16 public immutable SOURCE_CHAIN;

  uint256 constant GAS_LIMIT = 500_000;

  constructor(address _relayer, uint16 _sourceChain, uint16 _targetChain) {
    WORMHOLE_RELAYER = IWormholeRelayer(_relayer);
    SOURCE_CHAIN = _sourceChain;
    TARGET_CHAIN = _targetChain;
  }

  function quoteDeliveryCost(uint16 targetChain) public virtual returns (uint256 cost) {
    (cost,) = WORMHOLE_RELAYER.quoteEVMDeliveryPrice(targetChain, 0, GAS_LIMIT);
  }
}
