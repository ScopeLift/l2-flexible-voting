// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "openzeppelin/access/Ownable.sol";
import {IWormholeRelayer} from "wormhole/interfaces/relayer/IWormholeRelayer.sol";

contract WormholeBase is Ownable {
  /// @notice The wormhole relayer used to trustlessly send messages.
  IWormholeRelayer public immutable WORMHOLE_RELAYER;

  /// @param _relayer The address of the Wormhole relayer contract.
  /// @param _owner The address of the owner.
  constructor(address _relayer, address _owner) {
    WORMHOLE_RELAYER = IWormholeRelayer(_relayer);
    transferOwnership(_owner);
  }
}
