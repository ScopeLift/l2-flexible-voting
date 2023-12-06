// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {L2GovernorMetadata} from "src/L2GovernorMetadata.sol";
import {WormholeL2GovernorMetadataOptimizedHarness} from
  "test/harness/optimized/WormholeL2GovernorMetadataOptimizedHarness.sol";
import {TestConstants} from "test/Constants.sol";
import {L1BlockMock} from "test/mock/L1BlockMock.sol";

contract WormholeL2GovernorMetadataOptimizedTest is TestConstants {
  WormholeL2GovernorMetadataOptimizedHarness l2GovernorMetadata;
  L1BlockMock mockL1Block;

  function setUp() public {
    mockL1Block = new L1BlockMock();
    l2GovernorMetadata = new WormholeL2GovernorMetadataOptimizedHarness(
      L2_CHAIN.wormholeRelayer, msg.sender, address(mockL1Block)
    );
    vm.prank(l2GovernorMetadata.owner());
    l2GovernorMetadata.setRegisteredSender(
      L1_CHAIN.wormholeChainId, MOCK_WORMHOLE_SERIALIZED_ADDRESS
    );
  }
}

contract _AddProposal is WormholeL2GovernorMetadataOptimizedTest {
  function testFuzz_CorrectlyAddASingleProposal(
    uint256 proposalId,
    uint256 l1VoteStart,
    uint256 l1VoteEnd,
    bool isCanceled
  ) public {
    l1VoteEnd = mockL1Block.__boundL1VoteEnd(l1VoteEnd);
    l2GovernorMetadata.exposed_addProposal(proposalId, l1VoteStart, l1VoteEnd, isCanceled);
    L2GovernorMetadata.Proposal memory l2Proposal = l2GovernorMetadata.getProposal(proposalId);
    uint256 internalProposalId = l2GovernorMetadata.optimizedProposalIds(proposalId);

    assertEq(l2Proposal.voteStart, l1VoteStart, "Vote start has been incorrectly set");
    assertEq(l2Proposal.voteEnd, l1VoteEnd, "Vote end has been incorrectly set");
    assertEq(l2Proposal.isCanceled, isCanceled, "Canceled status of the vote is incorrect");
    assertEq(internalProposalId, 1, "Internal id is incorrect");
  }

  function testFuzz_CorrectlyAddAMultipleProposals(
    uint256 firstProposalId,
    uint256 firstL1VoteStart,
    uint256 firstL1VoteEnd,
    bool firstIsCanceled,
    uint256 secondL1VoteStart,
    uint256 secondL1VoteEnd,
    bool secondIsCanceled,
    uint256 thirdL1VoteStart,
    uint256 thirdL1VoteEnd,
    bool thirdIsCanceled
  ) public {
    uint256 secondProposalId = uint256(keccak256(abi.encodePacked(firstProposalId)));
    uint256 thirdProposalId = uint256(keccak256(abi.encodePacked(secondProposalId)));

    firstL1VoteEnd = mockL1Block.__boundL1VoteEnd(firstL1VoteEnd);
    secondL1VoteEnd = mockL1Block.__boundL1VoteEnd(secondL1VoteEnd);
    thirdL1VoteEnd = mockL1Block.__boundL1VoteEnd(thirdL1VoteEnd);

    l2GovernorMetadata.exposed_addProposal(
      firstProposalId, firstL1VoteStart, firstL1VoteEnd, firstIsCanceled
    );
    l2GovernorMetadata.exposed_addProposal(
      secondProposalId, secondL1VoteStart, secondL1VoteEnd, secondIsCanceled
    );
    l2GovernorMetadata.exposed_addProposal(
      thirdProposalId, thirdL1VoteStart, thirdL1VoteEnd, thirdIsCanceled
    );

    L2GovernorMetadata.Proposal memory thirdL2Proposal =
      l2GovernorMetadata.getProposal(thirdProposalId);
    uint256 thirdInternalProposalId = l2GovernorMetadata.optimizedProposalIds(thirdProposalId);

    assertEq(
      thirdL2Proposal.voteStart, thirdL1VoteStart, "Third vote start has been incorrectly set"
    );
    assertEq(thirdL2Proposal.voteEnd, thirdL1VoteEnd, "Third vote end has been incorrectly set");
    assertEq(
      thirdL2Proposal.isCanceled, thirdIsCanceled, "Third canceled status of the vote is incorrect"
    );
    assertEq(thirdInternalProposalId, 3, "Third internal id is incorrect");
  }

  function testFuzz_CorrectlyUpdateTheSameProposal(
    uint256 proposalId,
    uint256 initialVoteStart,
    uint256 initialVoteEnd,
    bool initialIsCanceled,
    uint256 updatedVoteStart,
    uint256 updatedVoteEnd,
    bool updatedIsCanceled
  ) public {
    initialVoteEnd = mockL1Block.__boundL1VoteEnd(initialVoteEnd);
    updatedVoteEnd = mockL1Block.__boundL1VoteEnd(updatedVoteEnd);
    l2GovernorMetadata.exposed_addProposal(
      proposalId, initialVoteStart, initialVoteEnd, initialIsCanceled
    );

    L2GovernorMetadata.Proposal memory l2Proposal = l2GovernorMetadata.getProposal(proposalId);
    uint256 initialInternalProposalId = l2GovernorMetadata.optimizedProposalIds(proposalId);

    assertEq(l2Proposal.voteStart, initialVoteStart, "Initial vote start has been incorrectly set");
    assertEq(l2Proposal.voteEnd, initialVoteEnd, "Initial vote end has been incorrectly set");
    assertEq(
      l2Proposal.isCanceled, initialIsCanceled, "Initial canceled status of the vote is incorrect"
    );
    assertEq(initialInternalProposalId, 1, "Initial internal id is incorrect");

    l2GovernorMetadata.exposed_addProposal(
      proposalId, updatedVoteStart, updatedVoteEnd, updatedIsCanceled
    );

    L2GovernorMetadata.Proposal memory updatedL2Proposal =
      l2GovernorMetadata.getProposal(proposalId);
    uint256 updatedInternalProposalId = l2GovernorMetadata.optimizedProposalIds(proposalId);

    assertEq(
      updatedL2Proposal.voteStart, updatedVoteStart, "Updated vote start has been incorrectly set"
    );
    assertEq(updatedL2Proposal.voteEnd, updatedVoteEnd, "Updated vote end has been incorrectly set");
    assertEq(
      updatedL2Proposal.isCanceled,
      updatedIsCanceled,
      "Updated canceled status of the vote is incorrect"
    );
    assertEq(updatedInternalProposalId, 1, "Updated internal id is incorrect");
  }
}
