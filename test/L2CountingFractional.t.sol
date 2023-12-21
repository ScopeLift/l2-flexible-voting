// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {TestConstants} from "test/Constants.sol";
import {L2CountingFractionalHarness} from "test/harness/L2CountingFractionalHarness.sol";

contract L2CountingFractionalTest is TestConstants {
  L2CountingFractionalHarness countingFractional;

  function setUp() public {
    countingFractional = new L2CountingFractionalHarness();
  }
}

contract COUNTING_MODE is L2CountingFractionalTest {
  function test_CorrectlyReceiveCountingMode() public {
    assertEq(
      countingFractional.COUNTING_MODE(),
      "support=bravo&quorum=for,abstain&params=fractional",
      "COUNTING_MODE is incorrect"
    );
  }
}

contract HasVoted is L2CountingFractionalTest {
  function testFuzz_AccountHasNotCastAVote(uint256 proposalId, address account) public {
    bool hasVoted = countingFractional.hasVoted(proposalId, account);
    assertFalse(hasVoted, "Account has voted");
  }

  function testFuzz_AccountHasCastAVoteWithCountVote(
    uint256 proposalId,
    address account,
    uint120 totalWeight
  ) public {
    vm.assume(totalWeight != 0);
    countingFractional.exposed_countVote(proposalId, account, 1, totalWeight, "");
    bool hasVoted = countingFractional.hasVoted(proposalId, account);
    assertTrue(hasVoted, "Account has not voted");
  }
}

contract VoteWeightCast is L2CountingFractionalTest {
  function testFuzz_AccountHasNotCastAVote(uint256 proposalId, address account) public {
    uint128 voteWeight = countingFractional.voteWeightCast(proposalId, account);
    assertEq(voteWeight, 0);
  }

  function testFuzz_AccountHasCastAVote(uint256 proposalId, address account, uint120 totalWeight)
    public
  {
    vm.assume(totalWeight != 0);
    countingFractional.exposed_countVote(proposalId, account, 1, totalWeight, "");
    uint128 voteWeight = countingFractional.voteWeightCast(proposalId, account);
    assertEq(voteWeight, totalWeight);
  }
}

contract ProposalVotes is L2CountingFractionalTest {
  function testFuzz_ProposalHasNotBeenCreatedYet(uint256 proposalId) public {
    (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) =
      countingFractional.proposalVotes(proposalId);
    assertEq(againstVotes, 0, "There are against votes");
    assertEq(forVotes, 0, "There are for votes");
    assertEq(abstainVotes, 0, "There are abstain votes");
  }

  function testFuzz_ProposalHasVotesCast(
    uint256 proposalId,
    uint128 against,
    uint128 inFavor,
    uint128 abstain
  ) public {
    countingFractional.workaround_createProposalVote(proposalId, against, inFavor, abstain);
    (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) =
      countingFractional.proposalVotes(proposalId);
    assertEq(againstVotes, against, "Against votes are incorrect");
    assertEq(forVotes, inFavor, "For votes are incorrect");
    assertEq(abstainVotes, abstain, "Abstain votes are incorrect");
  }
}

contract _CountVote is L2CountingFractionalTest {
  function testFuzz_RevertIf_AccountHasNoWeightOnProposal(
    uint256 proposalId,
    address account,
    uint8 support,
    bytes memory voteData
  ) public {
    support = uint8(bound(support, 0, 2));
    vm.expectRevert("GovernorCountingFractional: no weight");
    countingFractional.exposed_countVote(proposalId, account, support, 0, voteData);
  }

  function testFuzz_CorrectlySubmitCountVoteFractional(
    uint256 proposalId,
    address account,
    uint8 support,
    uint40 against,
    uint40 inFavor,
    uint40 abstain
  ) public {
    uint128 totalWeight = uint128(against) + inFavor + abstain;
    vm.assume(totalWeight != 0);

    bytes memory voteData = abi.encodePacked(uint128(against), uint128(inFavor), uint128(abstain));
    support = uint8(bound(support, 0, 2));
    countingFractional.exposed_countVote(proposalId, account, support, totalWeight, voteData);
  }

  function testFuzz_RevertIf_SubmittedVoteIsGreaterThanTheTotalWeight(
    uint256 proposalId,
    address account,
    uint8 support,
    uint128 totalWeight
  ) public {
    vm.assume(totalWeight != 0);
    support = uint8(bound(support, 0, 2));

    countingFractional.workaround_createProposalVoterWeightCast(proposalId, account, totalWeight);
    vm.expectRevert("GovernorCountingFractional: all weight cast");
    countingFractional.exposed_countVote(proposalId, account, support, 1, "");
  }
}

contract _CountVoteNominal is L2CountingFractionalTest {
  function testFuzz_CorrectlyTallyAgainstVote(
    uint256 proposalId,
    address account,
    uint128 totalWeight
  ) public {
    vm.assume(totalWeight != 0);

    countingFractional.exposed_countVoteNominal(proposalId, account, totalWeight, 0);
    (uint256 againstVotes,,) = countingFractional.proposalVotes(proposalId);
    assertEq(againstVotes, totalWeight, "Against votes are incorrect");
  }

  function testFuzz_CorrectlyTallyForVote(uint256 proposalId, address account, uint128 totalWeight)
    public
  {
    vm.assume(totalWeight != 0);

    countingFractional.exposed_countVoteNominal(proposalId, account, totalWeight, 1);
    (, uint256 forVotes,) = countingFractional.proposalVotes(proposalId);
    assertEq(forVotes, totalWeight, "For votes are incorrect");
  }

  function testFuzz_CorrectlyTallyAbstainVote(
    uint256 proposalId,
    address account,
    uint128 totalWeight
  ) public {
    vm.assume(totalWeight != 0);

    countingFractional.exposed_countVoteNominal(proposalId, account, totalWeight, 2);
    (,, uint256 abstainVotes) = countingFractional.proposalVotes(proposalId);
    assertEq(abstainVotes, totalWeight, "Abstain votes are incorrect");
  }

  function testFuzz_RevertIf_InvalidVote(
    uint256 proposalId,
    address account,
    uint128 totalWeight,
    uint8 support
  ) public {
    vm.assume(totalWeight != 0);
    support = uint8(bound(support, 3, type(uint8).max));

    vm.expectRevert(
      "GovernorCountingFractional: invalid support value, must be included in VoteType enum"
    );
    countingFractional.exposed_countVoteNominal(proposalId, account, totalWeight, support);
  }

  function testFuzz_RevertIf_VoteExceedsWeight(uint256 proposalId, address account) public {
    countingFractional.exposed_countVoteNominal(proposalId, account, 1, 0);
    vm.expectRevert("GovernorCountingFractional: vote would exceed weight");
    countingFractional.exposed_countVoteNominal(proposalId, account, 0, 0);
  }
}

contract _CountVoteFractional is L2CountingFractionalTest {
  function testFuzz_CorrectlyTallyVote(
    uint256 proposalId,
    address account,
    uint40 against,
    uint40 inFavor,
    uint40 abstain
  ) public {
    uint128 totalWeight = uint128(against) + inFavor + abstain;
    vm.assume(totalWeight != 0);
    bytes memory voteData = abi.encodePacked(uint128(against), uint128(inFavor), uint128(abstain));

    countingFractional.exposed_countVoteFractional(proposalId, account, totalWeight, voteData);
  }

  function testFuzz_RevertIf_VoteDataIsTooShort(
    uint256 proposalId,
    address account,
    uint40 against,
    uint40 inFavor,
    uint40 abstain
  ) public {
    uint128 totalWeight = uint120(against) + inFavor + abstain;
    vm.assume(totalWeight != 0);
    bytes memory voteData = abi.encodePacked(uint120(against), uint128(inFavor), uint128(abstain));

    vm.expectRevert("GovernorCountingFractional: invalid voteData");
    countingFractional.exposed_countVoteFractional(proposalId, account, totalWeight, voteData);
  }

  function testFuzz_RevertIf_VoteDataIsTooLong(
    uint256 proposalId,
    address account,
    uint40 against,
    uint40 inFavor,
    uint40 abstain
  ) public {
    uint128 totalWeight = uint120(against) + inFavor + abstain;
    vm.assume(totalWeight != 0);
    bytes memory voteData = abi.encodePacked(uint136(against), uint128(inFavor), uint128(abstain));

    vm.expectRevert("GovernorCountingFractional: invalid voteData");
    countingFractional.exposed_countVoteFractional(proposalId, account, totalWeight, voteData);
  }

  function testFuzz_RevertIf_VotingWeightHasBeenExceeded(
    uint256 proposalId,
    address account,
    uint40 against,
    uint40 inFavor,
    uint40 abstain
  ) public {
    uint128 totalWeight = 0;
    bytes memory voteData = abi.encodePacked(uint128(against), uint128(inFavor), uint128(abstain));

    vm.expectRevert("GovernorCountingFractional: vote would exceed weight");
    countingFractional.exposed_countVoteFractional(proposalId, account, totalWeight, voteData);
  }
}
