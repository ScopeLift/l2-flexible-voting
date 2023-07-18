// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {IWormhole} from "wormhole/interfaces/IWormhole.sol";
import {IWormholeRelayer} from "wormhole/interfaces/relayer/IWormholeRelayer.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";

abstract contract WormholeReceiver is Ownable {
  /// @notice The wormhole relayer used to trustlessly send messages.
  IWormholeRelayer private immutable WORMHOLE_RELAYER;

  constructor(address _relayer) {
    WORMHOLE_RELAYER = IWormholeRelayer(_relayer);
  }

  function receiveEncodedMsg(
    bytes memory payload,
    bytes[] memory additionalVaas,
    bytes32,
    uint16 sourceChain,
    bytes32 deliveryHash
  ) public virtual;

  modifier onlyRelayer() {
    require(msg.sender == address(WORMHOLE_RELAYER), "Only relayer allowed");
    _;
  }
}
