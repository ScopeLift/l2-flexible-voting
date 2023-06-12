// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;
// 
// import {Test} from "forge-std/Test.sol";
// import {ERC20} from "openzeppelin/token/ERC20/ERC20.sol";
// import {IERC20Mint} from "src/interfaces/IERC20Mint.sol";
// import {L2ERC20} from "src/L2ERC20.sol";
// import {L1Contracts} from "test/L1Contracts.sol";
// 
// 
// // TODO Add the most basic tests
// contract L2ERC20 is Test {
//   L2ERC20 erc20;
// 
//   function setUp() public {
//     vm.createSelectFork(vm.rpcUrl("polygon_mumbai"));
//     erc20 = new L2ERC20("Hello", "WRLD", wormholeCoreMumbai);
//   }
// }
// 
// contract ReceiveEncodedMsg is L1ERC20BridgeTest {
//   function testFork_CorrectlyDepositTokens() public {
//     L1ERC20Bridge bridge = new L1ERC20Bridge(address(erc20), wormholeCoreFuji);
// 	erc20.receiveEncodedMsg(abi.encode(address(this), 100));
//   }
// }
