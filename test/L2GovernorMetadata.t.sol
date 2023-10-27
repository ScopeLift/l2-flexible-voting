// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Strings.sol";

import {L2GovernorMetadata} from "src/L2GovernorMetadata.sol";
import {L2GovernorMetadataHarness} from "test/harness/L2GovernorMetadataHarness.sol";
import {TestConstants} from "test/Constants.sol";
import {L1BlockMock} from "test/mock/L1BlockMock.sol";

contract L2GovernorMetadataTest is TestConstants {
  L2GovernorMetadataHarness l2GovernorMetadata;
  L1BlockMock mockL1Block;

  uint64 constant MOCK_L1_BLOCK = 18_442_511;

  event ProposalCreated(
    uint256 proposalId,
    address proposer,
    address[] targets,
    uint256[] values,
    string[] signatures,
    bytes[] calldatas,
    uint256 startBlock,
    uint256 endBlock,
    string description
  );

  event ProposalCanceled(uint256 proposalId);

  function setUp() public {
    mockL1Block = new L1BlockMock();
    l2GovernorMetadata = new L2GovernorMetadataHarness(address(mockL1Block));
  }
}

/// @dev This also tests `getProposals` so we will omit a test contract for that method.
contract _addProposal is L2GovernorMetadataTest {
  function testFuzz_CorrectlyAddProposal(uint256 proposalId, uint256 voteStart, uint256 voteEnd)
    public
  {
    voteEnd = mockL1Block.__boundL1VoteEnd(voteEnd);

    vm.expectEmit();
    emit ProposalCreated(
      proposalId,
      address(0),
      new address[](0),
      new uint256[](0),
      new string[](0),
      new bytes[](0),
      block.number,
      mockL1Block.__expectedL2BlockForFutureBlock(voteEnd),
      string.concat("Mainnet proposal ", Strings.toString(proposalId))
    );

    l2GovernorMetadata.exposed_addProposal(proposalId, voteStart, voteEnd, false);
    L2GovernorMetadata.Proposal memory proposal = l2GovernorMetadata.exposed_proposals(proposalId);

    assertEq(proposal.voteStart, voteStart, "The voteStart has been set incorrectly");
    assertEq(proposal.voteEnd, voteEnd, "The voteEnd has been set incorrectly");
    assertEq(proposal.isCanceled, false, "The isCanceled has been set incorrectly");
  }

  function testFuzz_CorrectlyAddCanceledProposal(
    uint256 proposalId,
    uint256 voteStart,
    uint256 voteEnd
  ) public {
    vm.expectEmit();
    emit ProposalCanceled(proposalId);

    l2GovernorMetadata.exposed_addProposal(proposalId, voteStart, voteEnd, true);
    L2GovernorMetadata.Proposal memory proposal = l2GovernorMetadata.exposed_proposals(proposalId);

    assertEq(proposal.voteStart, voteStart, "The voteStart has been set incorrectly");
    assertEq(proposal.voteEnd, voteEnd, "The voteEnd has been set incorrectly");
    assertEq(proposal.isCanceled, true, "The isCanceled has been set incorrectly");
  }
}
