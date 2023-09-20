// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

contract Constants is Test {
  uint256 L1_CHAIN_ID = vm.envOr("L1_CHAIN_ID", uint256(43_113));
  uint256 L2_CHAIN_ID = vm.envOr("L2_CHAIN_ID", uint256(80_001));
  bool TESTNET = vm.envOr("TESTNET", true);
  bytes32 MOCK_WORMHOLE_SERIALIZED_ADDRESS =
    bytes32(uint256(uint160(0xEAC5F0d4A9a45E1f9FdD0e7e2882e9f60E301156)));
  Constants.ChainConfig L1_CHAIN;
  Constants.ChainConfig L2_CHAIN;

  mapping(uint256 => ChainConfig) public chainInfos;

  struct ChainConfig {
    uint16 wormholeChainId;
    address wormholeRelayer;
    uint256 chainId;
    string rpcUrl;
  }

  constructor() {
    _initChains();
    L1_CHAIN = chainInfos[L1_CHAIN_ID];
    L2_CHAIN = chainInfos[L2_CHAIN_ID];
  }

  function _initChains() internal {
    chainInfos[1] = ChainConfig({
      wormholeChainId: 2,
      wormholeRelayer: 0x27428DD2d3DD32A4D7f7C497eAaa23130d894911,
      chainId: 1,
      rpcUrl: vm.envOr("ETHEREUM_RPC_URL", string("https://eth.llamarpc.com"))
    });
    chainInfos[10] = ChainConfig({
      wormholeChainId: 24,
      wormholeRelayer: 0x27428DD2d3DD32A4D7f7C497eAaa23130d894911,
      chainId: 10,
      rpcUrl: vm.envOr("OPTIMISM_RPC_URL", string("https://optimism.publicnode.com"))
    });
    chainInfos[42_161] = ChainConfig({
      wormholeChainId: 23,
      wormholeRelayer: 0x27428DD2d3DD32A4D7f7C497eAaa23130d894911,
      chainId: 42_161,
      rpcUrl: vm.envOr("ARBITRUM_RPC_URL", string("https://rpc.ankr.com/arbitrum"))
    });
    chainInfos[43_113] = ChainConfig({
      wormholeChainId: 6,
      wormholeRelayer: 0xA3cF45939bD6260bcFe3D66bc73d60f19e49a8BB,
      chainId: 43_113,
      rpcUrl: vm.envOr("POLYGON_MUMBAI_RPC_URL", string("https://api.avax-test.network/ext/bc/C/rpc"))
    });
    chainInfos[80_001] = ChainConfig({
      wormholeChainId: 5,
      wormholeRelayer: 0x0591C25ebd0580E0d4F27A82Fc2e24E7489CB5e0,
      chainId: 80_001,
      rpcUrl: vm.envOr("AVALANCHE_FUJI_RPC_URL", string("https://rpc.ankr.com/polygon_mumbai"))
    });
  }

  function _toWormholeAddress(address addr) internal pure returns (bytes32) {
    return bytes32(uint256(uint160(addr)));
  }

}
