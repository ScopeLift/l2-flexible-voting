// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// 1. COUNTING_MODE
//   - Check string
// 2. hasVoted
//   - Vote zero
//   - Vote greater than 0
//   - Vote proposal missing
// 3. voteWeightCast
//   - cast greater than 0
//   - cast equal 0
//   - proposal missing
// 4. proposalvotes
//   - No proposal
//   - proposal has votes
// 5. _countVote
//   - Greater than total weight
//   - voteData greater than 0
//   - voteData equal to 0
// 6. _countVoteNaminal
//   - for
//   - abstain
//   - against
//   -  Invalid
// 7. _countVoteFractional
//   -  execeed weight
//   - under weight
//   - no weight
//   - vote data too long
//   - vote data too short

import {TestConstants} from "test/Constants.sol";
import {L2CountingFractionalHarness} from "test/harness/L2CountingFractionalHarness.sol";

contract L2CountingFractionalTest is TestConstants {
  L2CountingFractionalHarness countingFractional;

  function setUp() public {
    countingFractional = new L2CountingFractionalHarness();
  }
}

contract COUNTING_MODE is L2CountingFractionalTest {
  // Is this necessary
  // the quorum param doesn't make sense
  function test_CorrectlyReceiveCountingMode() public {
    assertEq(
      countingFractional.COUNTING_MODE(),
      "support=bravo&quorum=for,abstain&params=fractional",
      "COUNTING_MODE is incorrect"
    );
  }
}

contract HasVoted is L2CountingFractionalTest {
   function testFuzz_AccountHasNotCastAVote() public {}
   function testFuzz_AccountHasCastAVote() public {}
   function testFuzz_ProposalHasNotBeenCreatedYet() public {}
}

contract VoteWeightCast is L2CountingFractionalTest {
  // Is this necessary?
  function testFuzz_AccountHasNotCastAVote() public {}
  function testFuzz_AccountHasCastAVote() public {}
  function testFuzz_ProposalHasNotBeenCreatedYet() public {}
}

contract ProposalVotes is L2CountingFractionalTest {
  function testFuzz_ProposalHasNotBeenCreatedYet() public {}
  function testFuzz_ProposalHasVotesCast() public {}
  function testFuzz_ProposalHasNoVotesCast() public {}
}

contract _CountVote is L2CountingFractionalTest {}
