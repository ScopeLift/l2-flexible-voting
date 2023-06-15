// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {Script} from "forge-std/Script.sol";
import {FakeERC20} from "src/FakeERC20.sol";

contract DeployFakeERC20 is Script {
  function run() public {
    vm.broadcast();
    new FakeERC20("Governance", "GOV");
  }
}
