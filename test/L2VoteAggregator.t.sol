// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {L1Block} from "src/L1Block.sol";
import {L2VoteAggregator} from "src/L2VoteAggregator.sol";
import {FakeERC20} from "src/FakeERC20.sol";

import {Constants} from "test/Constants.sol";
import {GovernorMetadataMock} from "test/mock/GovernorMetadataMock.sol";

contract L2VoteAggregatorHarness is L2VoteAggregator {
  constructor(address _votingToken, address _governorMetadata, address _l1BlockAddress)
    L2VoteAggregator(_votingToken, _governorMetadata, _l1BlockAddress)
  {}

  function _bridgeVote(bytes memory) internal override {}
}

contract L2VoteAggregatorBase is Test, Constants {
  L2VoteAggregatorHarness voteAggregator;

  function setUp() public {
    GovernorMetadataMock l2GovernorMetadata = new GovernorMetadataMock(L2_CHAIN.wormholeRelayer);
    FakeERC20 l2Erc20 = new FakeERC20("GovExample", "GOV");
    L1Block l1Block = new L1Block();
    voteAggregator =
      new L2VoteAggregatorHarness(address(l2Erc20), address(l2GovernorMetadata), address(l1Block));
  }
}

contract VotingDelay is L2VoteAggregatorBase {
  function test_CorrectlyReturnVotingDelay() public {
    uint256 delay = voteAggregator.votingDelay();
    assertEq(delay, 0, "Delay should be 0 as we do not support this method.");
  }
}

contract VotingPeriod is L2VoteAggregatorBase {
  function test_CorrectlyReturnVotingPeriod() public {
    uint256 period = voteAggregator.votingPeriod();
    assertEq(period, 0, "Period should be 0 as we do not support this method.");
  }
}

contract ProposalThreshold is L2VoteAggregatorBase {
  function test_CorrectlyReturnProposalThreshold() public {
    uint256 threshold = voteAggregator.proposalThreshold();
    assertEq(threshold, 0, "Threshold should be 0 as we do not support this method.");
  }
}

// State tests

contract GetVotes is L2VoteAggregatorBase {
  function test_CorrectlyReturnGetVotes(address addr, uint256 blockNumber) public {
    uint256 votes = voteAggregator.getVotes(addr, blockNumber);
    assertEq(votes, 0, "Votes should be 0 as we do not support this method.");
  }
}

contract State is L2VoteAggregatorBase {
   function testFuzz_ReturnStatusBeforeVoteStart(uint256 _proposalId, uint32 _timeToProposalEnd) public {
     vm.assume(_proposalId != 0);
     vm.assume(_proposalId != 1);
     vm.assume(_timeToProposalEnd > voteAggregator.CAST_VOTE_WINDOW());

     vm.roll(block.number + 1);
     GovernorMetadataMock(address(voteAggregator.GOVERNOR_METADATA())).createProposal(_proposalId, _timeToProposalEnd);

     vm.roll(block.number - 1);
     L2VoteAggregator.ProposalState state = voteAggregator.state(_proposalId);
     assertEq(uint8(state), uint8(L2VoteAggregator.ProposalState.Pending), "The status before vote start should be pending");
  }

   function testFuzz_ReturnStatusWhileVoteActive(uint256 _proposalId, uint32 _timeToProposalEnd) public {
     vm.assume(_proposalId != 0);
     vm.assume(_proposalId != 1);
     vm.assume(_timeToProposalEnd > voteAggregator.CAST_VOTE_WINDOW());

     GovernorMetadataMock(address(voteAggregator.GOVERNOR_METADATA())).createProposal(_proposalId, _timeToProposalEnd);

     vm.roll(block.number + _timeToProposalEnd - voteAggregator.CAST_VOTE_WINDOW()); // Proposal is active
     L2VoteAggregator.ProposalState state = voteAggregator.state(_proposalId);
     assertEq(uint8(state), uint8(L2VoteAggregator.ProposalState.Active), "The status before vote start should be active");
  }

   function testFuzz_ReturnStatusWhileIsCancelled(uint256 _proposalId, uint32 _timeToProposalEnd) public {
     vm.assume(_proposalId != 0);
     vm.assume(_proposalId != 1);
     _timeToProposalEnd = uint32(bound(_timeToProposalEnd, voteAggregator.CAST_VOTE_WINDOW(), type(uint32).max));

     GovernorMetadataMock(address(voteAggregator.GOVERNOR_METADATA())).createProposal(_proposalId, _timeToProposalEnd, true);

     vm.roll(block.number + _timeToProposalEnd - voteAggregator.CAST_VOTE_WINDOW()); // Proposal is cancelled
     L2VoteAggregator.ProposalState state = voteAggregator.state(_proposalId);
     assertEq(uint8(state), uint8(L2VoteAggregator.ProposalState.Cancelled), "The status before vote start should be cancelled");
  }

   function testFuzz_ReturnStatusWhileIsExpired(uint256 _proposalId, uint32 _timeToProposalEnd) public {
     vm.assume(_proposalId != 0);
     vm.assume(_proposalId != 1);
     _timeToProposalEnd = uint32(bound(_timeToProposalEnd, voteAggregator.CAST_VOTE_WINDOW(), type(uint32).max));

     GovernorMetadataMock(address(voteAggregator.GOVERNOR_METADATA())).createProposal(_proposalId, _timeToProposalEnd, false);

     vm.roll(block.number + _timeToProposalEnd); // Proposal is expired
     L2VoteAggregator.ProposalState state = voteAggregator.state(_proposalId);
     assertEq(uint8(state), uint8(L2VoteAggregator.ProposalState.Expired), "The status before vote start should be expired");
  }
}

contract Propose is L2VoteAggregatorBase {
  function testFuzz_RevertIf_Called(address[] memory addrs, uint256[] memory exam, bytes[] memory te, string memory hi ) public {
    vm.expectRevert(L2VoteAggregator.UnsupportedMethod.selector);
    voteAggregator.propose(addrs, exam, te, hi);
  }
}

contract Execute is L2VoteAggregatorBase {
  function testFuzz_RevertIf_Called(address[] memory addrs, uint256[] memory exam, bytes[] memory te, bytes32 hi ) public {
    vm.expectRevert(L2VoteAggregator.UnsupportedMethod.selector);
    voteAggregator.execute(addrs, exam, te, hi);
  }
}

