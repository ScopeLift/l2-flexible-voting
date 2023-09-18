// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IWormholeRelayer} from "wormhole/interfaces/relayer/IWormholeRelayer.sol";

import {WormholeBase} from "src/WormholeBase.sol";
import {WormholeSender} from "src/WormholeSender.sol";

contract WormholeSenderHarness is WormholeSender {
  constructor(address _relayer, uint16 _sourceChain, uint16 _targetChain)
    WormholeBase(_relayer)
    WormholeSender(_sourceChain, _targetChain)
  {}

  function wormholeRelayer() public view returns (IWormholeRelayer) {
    return WORMHOLE_RELAYER;
  }
}
