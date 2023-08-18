// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {IWormholeRelayer} from "wormhole/interfaces/relayer/IWormholeRelayer.sol";

contract WormholeBase {
  /// @notice The wormhole relayer used to trustlessly send messages.
  IWormholeRelayer public immutable WORMHOLE_RELAYER;

  /// @param _relayer The address of the Wormhole relayer contract.
  constructor(address _relayer) {
    WORMHOLE_RELAYER = IWormholeRelayer(_relayer);
  }
}
