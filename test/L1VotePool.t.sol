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
  GovernorFlexibleVotingMock gov;

  event VoteCast(
    address indexed voter,
    uint256 proposalId,
    uint256 voteAgainst,
    uint256 voteFor,
    uint256 voteAbstain
  );

  function setUp() public {
    l1Erc20 = new FakeERC20("Hello", "WRLD");
    gov = new GovernorFlexibleVotingMock("Governor", ERC20VotesComp(address(l1Erc20)));
    l1VotePool = new L1VotePoolHarness(address(gov));
  }
}

contract Constructor is L1VotePoolTest {
  function testFuzz_CorrectlySetConstructorArgs() public {
    L1VotePool pool = new L1VotePoolHarness(address(gov));
    assertEq(
      address(pool.GOVERNOR()), address(gov), "The governor address has been set incorrectly."
    );
  }
}

contract _castVote is L1VotePoolTest {
  function testFuzz_CorrectlyCastVoteToGovernor(
    uint32 _againstVotes,
    uint32 _forVotes,
    uint32 _abstainVotes,
    address _token
  ) public {
    vm.assume(uint128(_againstVotes) + _forVotes + _abstainVotes != 0);

    uint128 totalVotes = uint128(_againstVotes) + _forVotes + _abstainVotes;
    l1Erc20.mint(address(this), totalVotes);
    l1Erc20.approve(address(this), totalVotes);
    l1Erc20.transferFrom(address(this), address(l1VotePool), totalVotes);

    vm.roll(block.number + 1); // To checkpoint erc20 mint
    uint256 _proposalId = l1VotePool.createProposalVote(_token);
    l1VotePool._jumpToActiveProposal(_proposalId);

    vm.expectEmit();
    emit VoteCast(address(this), _proposalId, _againstVotes, _forVotes, _abstainVotes);

    l1VotePool.exposed_castVote(
      _proposalId,
      L1VotePool.ProposalVote(uint128(_againstVotes), uint128(_forVotes), uint128(_abstainVotes))
    );

    // Governor votes
    (uint256 totalAgainstVotes, uint256 totalForVotes, uint256 totalAbstainVotes) =
      gov.proposalVotes(_proposalId);

    assertEq(totalAgainstVotes, _againstVotes, "Total Against value is incorrect");
    assertEq(totalForVotes, _forVotes, "Total For value is incorrect");
    assertEq(totalAbstainVotes, _abstainVotes, "Total Abstain value is incorrect");
  }
}
