// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20VotesComp} from
  "openzeppelin-flexible-voting/governance/extensions/GovernorVotesComp.sol";

import {FakeERC20} from "src/FakeERC20.sol";
import {L1VotePool} from "src/L1VotePool.sol";
import {L1VotePoolHarness} from "test/harness/L1VotePoolHarness.sol";
import {GovernorFlexibleVotingMock} from "test/mock/GovernorMock.sol";
import {TestConstants} from "test/Constants.sol";

contract L1VotePoolTest is TestConstants {
  L1VotePoolHarness l1VotePool;
  FakeERC20 l1Erc20;

  function setUp() public {
    l1Erc20 = new FakeERC20("Hello", "WRLD");
    GovernorFlexibleVotingMock gov =
      new GovernorFlexibleVotingMock("Governor", ERC20VotesComp(address(l1Erc20)));
    l1VotePool = L1VotePoolHarness(address(gov));
  }
}

contract Constructor is L1VotePoolTest {
  function testFuzz_CorrectlySetConstructorArgs(address _governor) public {
    vm.assume(_governor != address(0));
    L1VotePool pool = new L1VotePoolHarness(_governor);
    assertEq(address(pool.GOVERNOR()), _governor, "The governor address has been set incorrectly.");
  }
}

// This does not seem to working
// contract _castVote is L1VotePoolTest {
//   function testFuzz_CorrectlyCastVoteToGovernor(
//     uint256 _proposalId,
//     uint32 _againstVotes,
//     uint32 _forVotes,
//     uint32 _abstainVotes
//   ) public {
//     vm.assume(_proposalId != 0);
//     vm.assume(uint128(_againstVotes) + _forVotes + _abstainVotes != 0);
// 	// vm.assume(_forVotes + _abstainVotes <= type(uint256).max);
// 	// vm.assume(_againstVotes + _abstainVotes <= type(uint256).max);
//
//     l1Erc20.approve(address(l1VotePool), uint128(_againstVotes) + _forVotes + _abstainVotes);
// 	l1Erc20.mint(address(this), uint128(_againstVotes) + _forVotes + _abstainVotes);
//
//     l1VotePool.exposed_castVote(
//       _proposalId, L1VotePool.ProposalVote(uint128(_againstVotes), uint128(_forVotes),
// uint128(_abstainVotes))
//     );
//   }
// }
