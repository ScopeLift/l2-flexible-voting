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
    uint256 l1VoteStart,
    uint256 l1VoteEnd
  ) public {
    bytes memory payload = abi.encode(proposalId, l1VoteStart, l1VoteEnd);
    vm.prank(wormholeCoreMumbai);
    l2GovernorMetadata.receiveWormholeMessages(
      payload, new bytes[](0), bytes32(""), uint16(0), bytes32("")
    );
    L2GovernorMetadata.Proposal memory l2Proposal = l2GovernorMetadata.getProposal(proposalId);
    assertEq(l2Proposal.voteStart, l1VoteStart, "Vote start has been incorrectly set");
    assertEq(l2Proposal.voteEnd, l1VoteEnd, "Vote start has been incorrectly set");
  }

  function testFuzz_RevertIf_NotCalledByRelayer(
    uint256 proposalId,
    uint256 l1VoteStart,
    uint256 l1VoteEnd,
    address caller
  ) public {
    bytes memory payload = abi.encode(proposalId, l1VoteStart, l1VoteEnd);
    vm.assume(caller != wormholeCoreMumbai);
    vm.prank(caller);

    vm.expectRevert(WormholeReceiver.OnlyRelayerAllowed.selector);
    l2GovernorMetadata.receiveWormholeMessages(
      payload, new bytes[](0), bytes32(""), uint16(0), bytes32("")
    );
  }
}
