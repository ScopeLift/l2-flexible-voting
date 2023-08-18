// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {WormholeBase} from "src/WormholeBase.sol";
import {Constants} from "test/Constants.sol";

contract Constructor is Test, Constants {
  function testForkFuzz_CorrectlySetsAllArgs(address _wormholeRelayer) public {
    WormholeBase base = new WormholeBase(_wormholeRelayer);

    assertEq(
      address(base.WORMHOLE_RELAYER()), _wormholeRelayer, "Wormhole relayer is not set correctly"
    );
  }
}
