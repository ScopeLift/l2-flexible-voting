// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {Script} from "forge-std/Script.sol";
import {FakeERC20} from "src/FakeERC20.sol";

/// @dev Deploys an ERC20 on any chain. It is used to create a token for the L1 Governor when testing.
contract DeployFakeERC20 is Script {
  function run() public {
    // Deploy ERC20Votes
    vm.broadcast();
    new FakeERC20("Governance", "GOV");
  }
}
