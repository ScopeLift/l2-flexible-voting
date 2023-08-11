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
    new L2GovernorMetadata(wormholeCore); // nothing to assert as there are no constructor args set
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

  function testFuzz_CorrectlySaveProposalMetadataForTwoProposals(
    uint256 firstProposalId,
    uint256 firstVoteStart,
    uint256 firstVoteEnd,
    uint256 secondProposalId,
    uint256 secondVoteStart,
    uint256 secondVoteEnd
  ) public {
    vm.assume(firstProposalId != secondProposalId);

    bytes memory firstPayload = abi.encode(firstProposalId, firstVoteStart, firstVoteEnd);
    vm.prank(L2_CHAIN.wormholeRelayer);
    l2GovernorMetadata.receiveWormholeMessages(
      firstPayload, new bytes[](0), bytes32(""), uint16(0), bytes32("")
    );

    bytes memory secondPayload = abi.encode(secondProposalId, secondVoteStart, secondVoteEnd);
    vm.prank(L2_CHAIN.wormholeRelayer);
    l2GovernorMetadata.receiveWormholeMessages(
      secondPayload, new bytes[](0), bytes32(""), uint16(0), bytes32("")
    );

    L2GovernorMetadata.Proposal memory firstProposal =
      l2GovernorMetadata.getProposal(firstProposalId);
    assertEq(
      firstProposal.voteStart, firstVoteStart, "First proposal vote start has been incorrectly set"
    );
    assertEq(
      firstProposal.voteEnd, firstVoteEnd, "First proposal vote start has been incorrectly set"
    );

    L2GovernorMetadata.Proposal memory secondProposal =
      l2GovernorMetadata.getProposal(secondProposalId);
    assertEq(
      secondProposal.voteStart,
      secondVoteStart,
      "Second proposal vote start has been incorrectly set"
    );
    assertEq(
      secondProposal.voteEnd, secondVoteEnd, "Second proposal vote start has been incorrectly set"
    );
  }

  function testFuzz_RevertIfNotCalledByRelayer(
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
