// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {CommonBase} from "forge-std/Base.sol";

contract BaseConstants is CommonBase {
  BaseConstants.ChainConfig L1_CHAIN;
  BaseConstants.ChainConfig L2_CHAIN;
  uint256 immutable L1_CHAIN_ID = vm.envOr("L1_CHAIN_ID", uint256(43_113));
  uint256 immutable L2_CHAIN_ID = vm.envOr("L2_CHAIN_ID", uint256(80_001));
  bool immutable TESTNET = vm.envOr("TESTNET", true);

  struct ChainConfig {
    uint16 wormholeChainId;
    address wormholeRelayer;
    uint256 chainId;
    string rpcUrl;
  }

  mapping(uint256 chainId => ChainConfig) public chainInfos;

  constructor() {
    _initChains();
    L1_CHAIN = chainInfos[L1_CHAIN_ID];
    L2_CHAIN = chainInfos[L2_CHAIN_ID];
  }

  function _initChains() internal {
    if (TESTNET) {
      chainInfos[5] = ChainConfig({
        wormholeChainId: 2,
        wormholeRelayer: 0x28D8F1Be96f97C1387e94A53e00eCcFb4E75175a,
        chainId: 5,
        rpcUrl: vm.envOr("GOERLI_RPC_URL", string("https://ethereum-goerli.publicnode.com"))
      });
      chainInfos[420] = ChainConfig({
        wormholeChainId: 24,
        wormholeRelayer: 0x01A957A525a5b7A72808bA9D10c389674E459891,
        chainId: 420,
        rpcUrl: vm.envOr("OPTIMISM_GOERLI_RPC_URL", string("https://optimism.publicnode.com"))
      });
      chainInfos[43_113] = ChainConfig({
        wormholeChainId: 6,
        wormholeRelayer: 0xA3cF45939bD6260bcFe3D66bc73d60f19e49a8BB,
        chainId: 43_113,
        rpcUrl: vm.envOr(
          "AVALANCHE_FUJI_RPC_URL", string("https://api.avax-test.network/ext/bc/C/rpc")
          )
      });
      chainInfos[80_001] = ChainConfig({
        wormholeChainId: 5,
        wormholeRelayer: 0x0591C25ebd0580E0d4F27A82Fc2e24E7489CB5e0,
        chainId: 80_001,
        rpcUrl: vm.envOr("POLYGON_MUMBAI_RPC_URL", string("https://rpc.ankr.com/polygon_mumbai"))
      });
      return;
    }
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
    chainInfos[5] = ChainConfig({
      wormholeChainId: 2,
      wormholeRelayer: 0x28D8F1Be96f97C1387e94A53e00eCcFb4E75175a,
      chainId: 5,
      rpcUrl: vm.envOr("GOERLI_RPC_URL", string("https://rpc.ankr.com/eth_goerli"))
    });
    chainInfos[420] = ChainConfig({
      wormholeChainId: 24,
      wormholeRelayer: 0x01A957A525a5b7A72808bA9D10c389674E459891,
      chainId: 420,
      rpcUrl: vm.envOr("OPTIMISM_GOERLI_RPC_URL", string("https://optimism-goerli.publicnode.com"))
    });
  }

  function _toWormholeAddress(address addr) internal pure returns (bytes32) {
    return bytes32(uint256(uint160(addr)));
  }
}

contract ScriptConstants is BaseConstants {}

contract TestConstants is BaseConstants, Test {
  bytes32 MOCK_WORMHOLE_SERIALIZED_ADDRESS =
    bytes32(uint256(uint160(0xEAC5F0d4A9a45E1f9FdD0e7e2882e9f60E301156)));
}
