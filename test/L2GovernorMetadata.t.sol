// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {L2GovernorMetadata} from "src/L2GovernorMetadata.sol";
import {Constants} from "test/Constants.sol";
import {WormholeReceiver} from "src/WormholeReceiver.sol";

contract L2GovernorMetadataTest is Constants, Test {
  L2GovernorMetadata l2GovernorMetadata;

  function setUp() public {
    l2GovernorMetadata = new L2GovernorMetadata(wormholeCoreMumbai);
  }
}

contract Constructor is L2GovernorMetadataTest {
  function testFuzz_CorrectlySetsAllArgs(address wormholeCore) public {
    L2GovernorMetadata l2Gov = new L2GovernorMetadata(wormholeCore); // nothing to assert as
  }
}

contract ReceiveWormholeMessages is L2GovernorMetadataTest {
  function testFuzz_CorrectlySaveProposalMetadata(
    uint256 proposalId,
    uint256 voteStart,
    uint256 voteEnd
  ) public {
    bytes memory payload = abi.encode(proposalId, voteStart, voteEnd);
    vm.prank(wormholeCoreMumbai);
    l2GovernorMetadata.receiveWormholeMessages(
      payload, new bytes[](0), bytes32(""), uint16(0), bytes32("")
    );
    L2GovernorMetadata.Proposal memory proposal = l2GovernorMetadata.getProposal(proposalId);
    assertEq(proposal.voteStart, voteStart, "Vote start has been incorrectly set");
    assertEq(proposal.voteEnd, voteEnd, "Vote start has been incorrectly set");
  }

  function testFuzz_RevertIfNotCalledByRelayer(
    uint256 proposalId,
    uint256 voteStart,
    uint256 voteEnd,
    address caller
  ) public {
    bytes memory payload = abi.encode(proposalId, voteStart, voteEnd);
	vm.assume(caller != wormholeCoreMumbai);
    vm.prank(caller);
    vm.expectRevert(WormholeReceiver.OnlyRelayerAllowed.selector);
    l2GovernorMetadata.receiveWormholeMessages(
      payload, new bytes[](0), bytes32(""), uint16(0), bytes32("")
    );
  }
}
