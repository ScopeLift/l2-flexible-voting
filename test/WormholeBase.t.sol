// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {WormholeBase} from "src/WormholeBase.sol";
import {TestConstants} from "test/Constants.sol";

contract Constructor is Test, TestConstants {
  function testForkFuzz_CorrectlySetsAllArgs(address _wormholeRelayer) public {
    WormholeBase base = new WormholeBase(_wormholeRelayer);

    assertEq(
      address(base.WORMHOLE_RELAYER()), _wormholeRelayer, "Wormhole relayer is not set correctly"
    );
  }
}
