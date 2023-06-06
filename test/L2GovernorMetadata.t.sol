// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {L2GovernorMetadata} from "src/L2GovernorMetadata.sol";
import {Constants} from "test/Constants.sol";

contract L2GovernorMetadataTest is Test, Constants {
  L2GovernorMetadata l2GovernorMetadata;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl("polygon_mumbai"));
    l2GovernorMetadata = new L2GovernorMetadata(wormholeCoreMumbai);
    l2GovernorMetadata.registerApplicationContracts(
      6, bytes32(uint256(uint160(address(0x628C44d859d17aD932960DFcE226F5de427f9d6D))))
    );
  }
}

contract ReceiveEndcodedMsg is L2GovernorMetadataTest {
  function testFork_CorrectlyStoreMetadata() public {
    // Encoded message was generated from transaction
    // 0x873dab653e1a8a746a8e4f51eb0e1de46f878255312e18506301e3cc5cb29954
    // on Avalanche Fuji
    l2GovernorMetadata.receiveEncodedMsg(
      hex"01000000000100643f702e8fcb9eb6999b9f8950845f449dc257fade56c5f5d39e30d6cc8eed415c1e634d651a6de79e641d0e7d1ce13d828d95e64b4fec570f840012828b762f006490867d000000030006000000000000000000000000628c44d859d17ad932960dfce226f5de427f9d6d0000000000000003013b16cb6bd01a5bf0aedd40b736c5da6ee6a6d1a44a0bd327cb4942345972b6a6000000000000000000000000000000000000000000000000000000000163309f00000000000000000000000000000000000000000000000000000000016330af"
    );
  }
}
