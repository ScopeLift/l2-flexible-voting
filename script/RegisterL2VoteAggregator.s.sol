// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {Script, stdJson} from "forge-std/Script.sol";

import {L1ERC20Bridge} from "src/L1ERC20Bridge.sol";
import {Constants} from "test/Constants.sol";

/// @dev Registers the L2VoteAggregator address and chain id on the L1ERC20Bridge so the it can
/// receive vote messages.
contract RegisterL2VoteAggregator is Script, Constants {
  using stdJson for string;

  function run() public {
    // Get the L1 bridge contract address
    string memory bridgeFile = "broadcast/multi/Deploy.s.sol-latest/run.json";
    string memory bridgeJson = vm.readFile(bridgeFile);
    address l1Bridge = bridgeJson.readAddress(".deployments[1].transactions[1].contractAddress");

    // Get the L2 vote aggregator contract address
    string memory voteAggregatorFile = "broadcast/multi/DeployVoteAggregator.s.sol-latest/run.json";
    string memory voteAggregatorJson = vm.readFile(voteAggregatorFile);
    address voteAggregator =
      voteAggregatorJson.readAddress(".deployments[1].transactions[0].contractAddress");

    setFallbackToDefaultRpcUrls(false);
    vm.createSelectFork(getChain("avalanche_fuji").rpcUrl);

    // Register the L2 vote aggregator on the L1 bridge
    vm.broadcast();
    L1ERC20Bridge(l1Bridge).registerApplicationContracts(
      wormholePolygoniId, bytes32(uint256(uint160(voteAggregator)))
    );
  }
}
