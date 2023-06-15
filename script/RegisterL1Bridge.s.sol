// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {Script, stdJson} from "forge-std/Script.sol";
import {L1ERC20Bridge} from "src/L1ERC20Bridge.sol";
import {L2ERC20} from "src/L2ERC20.sol";
import {console2} from "forge-std/console2.sol";
import {IERC20Receive} from "src/interfaces/IERC20Mint.sol";
import {console2} from "forge-std/console2.sol";

contract RegisterL1Bridge is Script {
  using stdJson for string;

  function run() public {
    // Deploy the bridge
    // then deploy the erc20Votes token
    //
    // Avalanche is mimicking the L1
    address core = 0x7bbcE28e64B3F8b84d876Ab298393c38ad7aac4C;
    uint16 targetChain = 6;
    string memory file = "broadcast/multi/Deploy.s.sol-latest/run.json";
    string memory json = vm.readFile(file);

    address l2ERC20 = json.readAddress(".deployments[0].transactions[0].contractAddress");
    address l1Bridge = json.readAddress(".deployments[1].transactions[0].contractAddress");
    console2.logAddress(l1Bridge);
    console2.logAddress(l2ERC20);
    setFallbackToDefaultRpcUrls(false);

    vm.createSelectFork(getChain("polygon_mumbai").rpcUrl);

    vm.broadcast();
    IERC20Receive(l2ERC20).registerApplicationContracts(
      targetChain, bytes32(uint256(uint160(l1Bridge)))
    );
  }
}
