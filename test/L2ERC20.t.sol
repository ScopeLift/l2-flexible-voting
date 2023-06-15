// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {IERC20Mint} from "src/interfaces/IERC20Mint.sol";
import {L2ERC20} from "src/L2ERC20.sol";
import {L1Contracts} from "test/L1Contracts.sol";

// TODO Add the most basic tests
contract L2ERC20Test is Test {
  L2ERC20 erc20;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl("polygon_mumbai"));
    erc20 = new L2ERC20("Hello", "WRLD", 0x0CBE91CF822c73C2315FB05100C2F714765d5c20);
    erc20.registerApplicationContracts(
      6, bytes32(uint256(uint160(0x76763243e202BB4153DDe5a7CE4013a9564f06Ad)))
    );
  }
}

contract ReceiveEncodedMsg is L2ERC20Test {
  function testFork_CorrectlyDepositTokens() public {
    erc20.receiveEncodedMsg(
      hex"010000000001003f91c63d47c88eb78c6bac8774f515bf65536a60e3d8b880cd163e99d9d3df6b5fafb4134dce30face38207fe4feb717495584228a2e59efadff499441fe07e100648a60fd0000000b000600000000000000000000000076763243e202bb4153dde5a7ce4013a9564f06ad000000000000000b01000000000000000000000000eac5f0d4a9a45e1f9fdd0e7e2882e9f60e30115600000000000000000000000000000000000000000000000000000000000186a0"
    );
  }
}
