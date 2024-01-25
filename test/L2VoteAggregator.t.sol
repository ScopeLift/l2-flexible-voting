// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {L1Block} from "src/L1Block.sol";
import {L2GovernorMetadata} from "src/L2GovernorMetadata.sol";
import {L2VoteAggregator} from "src/L2VoteAggregator.sol";
import {FakeERC20} from "src/FakeERC20.sol";
import {WormholeL2GovernorMetadata} from "src/WormholeL2GovernorMetadata.sol";

import {TestConstants} from "test/Constants.sol";
import {GovernorMetadataMock} from "test/mock/GovernorMetadataMock.sol";
import {L2VoteAggregatorHarness} from "test/harness/L2VoteAggregatorHarness.sol";

contract L2VoteAggregatorTest is TestConstants {
  L2VoteAggregatorHarness voteAggregator;

  event VoteCast(
    address indexed voter, uint256 proposalId, uint8 support, uint256 weight, string reason
  );

  event VoteCastWithParams(
    address indexed voter,
    uint256 proposalId,
    uint8 support,
    uint256 weight,
    string reason,
    bytes params
  );

  event VoteBridged(
    uint256 indexed proposalId, uint256 voteAgainst, uint256 voteFor, uint256 voteAbstain
  );

  FakeERC20 l2Erc20;
  address voterAddress;
  uint256 privateKey;

  function setUp() public {
    (voterAddress, privateKey) = makeAddrAndKey("voter");
    l2Erc20 = new FakeERC20("GovExample", "GOV");
    L1Block l1Block = new L1Block();
    voteAggregator = new L2VoteAggregatorHarness(address(l2Erc20), address(l1Block));
  }
}

contract Constructor is TestConstants {
  function testForkFuzz_CorrectlySetAllArgs(address l2Erc20, address l1Block) public {
    L2VoteAggregator aggregator = new L2VoteAggregatorHarness(l2Erc20, l1Block);

    assertEq(address(aggregator.VOTING_TOKEN()), l2Erc20, "L2 token is not set correctly");
    assertEq(address(aggregator.L1_BLOCK()), l1Block, "L1 block is not set correctly");
  }
}

contract Initialize is L2VoteAggregatorTest {
  function testFork_CorrectlyInitializeL1Bridge(address bridgeAddress) public {
    voteAggregator.initialize(bridgeAddress);
    assertEq(
      voteAggregator.L1_BRIDGE_ADDRESS(), bridgeAddress, "L1 bridge address is not setup correctly"
    );
    assertTrue(voteAggregator.INITIALIZED(), "Vote aggregator isn't initialized");
  }

  function testFork_RevertWhen_AlreadyInitializedWithBridgeAddress(address bridgeAddress) public {
    voteAggregator.initialize(bridgeAddress);

    vm.expectRevert(L2VoteAggregator.AlreadyInitialized.selector);
    voteAggregator.initialize(bridgeAddress);
  }
}

contract VotingDelay is L2VoteAggregatorTest {
  function test_CorrectlyReturnVotingDelay() public {
    uint256 delay = voteAggregator.votingDelay();
    assertEq(delay, 0, "Delay should be 0 as we do not support this method.");
  }
}

contract VotingPeriod is L2VoteAggregatorTest {
  function test_CorrectlyReturnVotingPeriod() public {
    uint256 period = voteAggregator.votingPeriod();
    assertEq(period, 0, "Period should be 0 as we do not support this method.");
  }
}

contract ProposalThreshold is L2VoteAggregatorTest {
  function test_CorrectlyReturnProposalThreshold() public {
    uint256 threshold = voteAggregator.proposalThreshold();
    assertEq(threshold, 0, "Threshold should be 0 as we do not support this method.");
  }
}

contract Quorum is L2VoteAggregatorTest {
  function test_CorrectlyReturnProposalThreshold() public {
    uint256 quorum = voteAggregator.quorum(1);
    assertEq(quorum, 0, "Quorum should be 0 as we do not support this method.");
  }
}

contract GetVotes is L2VoteAggregatorTest {
  function test_CorrectlyReturnGetVotes(address addr, uint256 blockNumber) public {
    uint256 votes = voteAggregator.getVotes(addr, blockNumber);
    assertEq(votes, 0, "Votes should be 0 as we do not support this method.");
  }
}

contract State is L2VoteAggregatorTest {
  function testFuzz_ReturnStatusBeforeVoteStart(uint256 _proposalId, uint32 _timeToProposalEnd)
    public
  {
    vm.assume(_proposalId != 1); // Hardcoded proposal in mock
    vm.assume(_timeToProposalEnd > voteAggregator.CAST_VOTE_WINDOW());

    vm.roll(block.number + 1);
    voteAggregator.createProposal(_proposalId, _timeToProposalEnd);

    vm.roll(block.number - 1);
    L2VoteAggregator.ProposalState state = voteAggregator.state(_proposalId);
    assertEq(
      uint8(state),
      uint8(L2VoteAggregator.ProposalState.Pending),
      "The status before vote start should be pending"
    );
  }

  function testFuzz_ReturnStatusWhileVoteActive(uint256 _proposalId, uint32 _timeToProposalEnd)
    public
  {
    vm.assume(_proposalId != 1); // Hardcoded proposal in mock
    vm.assume(_timeToProposalEnd > voteAggregator.CAST_VOTE_WINDOW());

    voteAggregator.createProposal(_proposalId, _timeToProposalEnd);

    vm.roll(block.number + _timeToProposalEnd - voteAggregator.CAST_VOTE_WINDOW()); // Proposal is
      // active
    L2VoteAggregator.ProposalState state = voteAggregator.state(_proposalId);
    assertEq(
      uint8(state),
      uint8(L2VoteAggregator.ProposalState.Active),
      "The status before vote start should be active"
    );
  }

  function testFuzz_ReturnStatusWhileIsCanceled(uint256 _proposalId, uint32 _timeToProposalEnd)
    public
  {
    vm.assume(_proposalId != 1); // Hardcoded proposal in mock
    _timeToProposalEnd =
      uint32(bound(_timeToProposalEnd, voteAggregator.CAST_VOTE_WINDOW(), type(uint32).max));

    voteAggregator.createProposal(_proposalId, _timeToProposalEnd, true);

    vm.roll(block.number + _timeToProposalEnd - voteAggregator.CAST_VOTE_WINDOW()); // Proposal is
      // canceled
    L2VoteAggregator.ProposalState state = voteAggregator.state(_proposalId);
    assertEq(
      uint8(state), uint8(L2VoteAggregator.ProposalState.Canceled), "The status should be canceled"
    );
  }

  function testFuzz_ReturnStatusWhileExpired(uint256 _proposalId, uint32 _timeToProposalEnd) public {
    vm.assume(_proposalId != 1); // Hardcoded proposal in mock
    _timeToProposalEnd =
      uint32(bound(_timeToProposalEnd, voteAggregator.CAST_VOTE_WINDOW(), type(uint32).max));

    voteAggregator.createProposal(_proposalId, _timeToProposalEnd, false);

    vm.roll(block.number + _timeToProposalEnd); // Proposal is expired
    L2VoteAggregator.ProposalState state = voteAggregator.state(_proposalId);
    assertEq(
      uint8(state), uint8(L2VoteAggregator.ProposalState.Expired), "The status should be expired"
    );
  }
}

contract CastVote is L2VoteAggregatorTest {
  function testFuzz_RevertWhen_BeforeProposalStart(uint96 _amount, uint8 _support) public {
    vm.assume(_support < 3);
    L2VoteAggregator.VoteType _voteType = L2VoteAggregator.VoteType(_support);

    voteAggregator.createProposal(1, 3000, false);

    l2Erc20.mint(address(this), _amount);

    vm.roll(block.number - 1);
    vm.expectRevert(L2VoteAggregator.ProposalInactive.selector);
    voteAggregator.castVote(1, _voteType);
  }

  function testFuzz_RevertWhen_ProposalCanceled(uint96 _amount, uint8 _support, uint256 _proposalId)
    public
  {
    vm.assume(_amount != 0);
    vm.assume(_support < 3);
    L2VoteAggregator.VoteType _voteType = L2VoteAggregator.VoteType(_support);
    l2Erc20.mint(address(this), _amount);

    // In the setup we use a mock contract rather than the actual contract
    L2GovernorMetadata.Proposal memory l2Proposal =
      voteAggregator.createProposal(_proposalId, 1200, true);

    vm.roll(l2Proposal.voteStart + 1);
    vm.expectRevert(L2VoteAggregator.ProposalInactive.selector);
    voteAggregator.castVote(_proposalId, _voteType);
  }

  function testFuzz_RevertWhen_AfterCastWindow(
    uint96 _amount,
    uint8 _support,
    uint256 _proposalId,
    uint64 _proposalDuration
  ) public {
    vm.assume(_amount != 0);
    vm.assume(_support < 3);
    L2VoteAggregator.VoteType _voteType = L2VoteAggregator.VoteType(_support);

    _proposalDuration = uint64(
      bound(_proposalDuration, voteAggregator.CAST_VOTE_WINDOW(), type(uint64).max - block.number)
    );

    // In the setup we use a mock contract rather than the actual contract
    L2GovernorMetadata.Proposal memory l2Proposal =
      voteAggregator.createProposal(_proposalId, _proposalDuration);

    vm.roll(l2Proposal.voteStart - 1);
    l2Erc20.mint(address(this), _amount);

    // Our active check is inclusive so we need to add 1
    vm.roll(l2Proposal.voteStart + (_proposalDuration - voteAggregator.CAST_VOTE_WINDOW()) + 1);
    vm.expectRevert(L2VoteAggregator.ProposalInactive.selector);
    voteAggregator.castVote(_proposalId, _voteType);
  }

  function testFuzz_RevertWhen_VoterHasAlreadyVoted(uint96 _amount, uint8 _support) public {
    vm.assume(_amount != 0);
    vm.assume(_support < 3);
    L2VoteAggregator.VoteType _voteType = L2VoteAggregator.VoteType(_support);

    l2Erc20.mint(address(this), _amount);

    L2GovernorMetadata.Proposal memory l2Proposal = voteAggregator.createProposal(1, 3000, false);

    vm.roll(l2Proposal.voteStart + 1);
    voteAggregator.castVote(1, _voteType);

    vm.expectRevert("L2CountingFractional: all weight cast");
    voteAggregator.castVote(1, _voteType);
  }

  function testFuzz_RevertWhen_VoterHasNoWeight(uint96 _amount, uint8 _support) public {
    vm.assume(_amount != 0);
    vm.assume(_support < 3);
    L2VoteAggregator.VoteType _voteType = L2VoteAggregator.VoteType(_support);

    L2GovernorMetadata.Proposal memory l2Proposal = voteAggregator.createProposal(1, 3000, false);

    vm.roll(l2Proposal.voteStart + 1);
    vm.expectRevert(L2VoteAggregator.NoWeight.selector);
    voteAggregator.castVote(1, _voteType);
  }

  function testFuzz_CorrectlyCastVoteAgainst(uint96 _amount) public {
    vm.assume(_amount != 0);
    l2Erc20.mint(address(this), _amount);

    L2GovernorMetadata.Proposal memory l2Proposal = voteAggregator.createProposal(1, 3000, false);

    vm.roll(l2Proposal.voteStart + 1);
    vm.expectEmit();
    emit VoteCast(address(this), 1, 0, _amount, "");

    voteAggregator.castVote(1, L2VoteAggregator.VoteType.Against);
    (uint256 against,,) = voteAggregator.proposalVotes(1);
    assertEq(against, _amount, "Votes against is not correct");
  }

  function testFuzz_CorrectlyCastVoteAbstain(uint96 _amount) public {
    vm.assume(_amount != 0);
    l2Erc20.mint(address(this), _amount);

    L2GovernorMetadata.Proposal memory l2Proposal = voteAggregator.createProposal(1, 3000, false);

    vm.roll(l2Proposal.voteStart + 1);
    vm.expectEmit();
    emit VoteCast(address(this), 1, 2, _amount, "");

    voteAggregator.castVote(1, L2VoteAggregator.VoteType.Abstain);
    (,, uint256 abstain) = voteAggregator.proposalVotes(1);

    assertEq(abstain, _amount, "Votes abstain is not correct");
  }

  function testFuzz_CorrectlyCastVoteFor(uint96 _amount) public {
    vm.assume(_amount != 0);
    l2Erc20.mint(address(this), _amount);

    L2GovernorMetadata.Proposal memory l2Proposal = voteAggregator.createProposal(1, 3000, false);

    vm.roll(l2Proposal.voteStart + 1);
    vm.expectEmit();
    emit VoteCast(address(this), 1, 1, _amount, "");

    voteAggregator.castVote(1, L2VoteAggregator.VoteType.For);
    (, uint256 forVotes,) = voteAggregator.proposalVotes(1);

    assertEq(forVotes, _amount, "Votes for is not correct");
  }
}

contract CastVoteWithReason is L2VoteAggregatorTest {
  function testFuzz_RevertWhen_BeforeProposalStart(
    uint96 _amount,
    uint8 _support,
    string memory reason
  ) public {
    vm.assume(_support < 3);
    L2VoteAggregator.VoteType _voteType = L2VoteAggregator.VoteType(_support);

    voteAggregator.createProposal(1, 3000, false);

    l2Erc20.mint(address(this), _amount);

    vm.roll(block.number - 1);
    vm.expectRevert(L2VoteAggregator.ProposalInactive.selector);
    voteAggregator.castVoteWithReason(1, _voteType, reason);
  }

  function testFuzz_RevertWhen_ProposalCanceled(
    uint96 _amount,
    uint8 _support,
    uint256 _proposalId,
    string memory reason
  ) public {
    vm.assume(_amount != 0);
    vm.assume(_support < 3);
    L2VoteAggregator.VoteType _voteType = L2VoteAggregator.VoteType(_support);
    l2Erc20.mint(address(this), _amount);

    // In the setup we use a mock contract rather than the actual contract
    L2GovernorMetadata.Proposal memory l2Proposal =
      voteAggregator.createProposal(_proposalId, 1200, true);

    vm.roll(l2Proposal.voteStart + 1);
    vm.expectRevert(L2VoteAggregator.ProposalInactive.selector);
    voteAggregator.castVoteWithReason(_proposalId, _voteType, reason);
  }

  function testFuzz_RevertWhen_AfterCastWindow(
    uint96 _amount,
    uint8 _support,
    uint256 _proposalId,
    uint64 _proposalDuration,
    string memory reason
  ) public {
    vm.assume(_amount != 0);
    vm.assume(_support < 3);
    L2VoteAggregator.VoteType _voteType = L2VoteAggregator.VoteType(_support);

    _proposalDuration = uint64(
      bound(_proposalDuration, voteAggregator.CAST_VOTE_WINDOW(), type(uint64).max - block.number)
    );

    // In the setup we use a mock contract rather than the actual contract
    L2GovernorMetadata.Proposal memory l2Proposal =
      voteAggregator.createProposal(_proposalId, _proposalDuration);

    vm.roll(l2Proposal.voteStart - 1);
    l2Erc20.mint(address(this), _amount);

    // Our active check is inclusive so we need to add 1
    vm.roll(l2Proposal.voteStart + (_proposalDuration - voteAggregator.CAST_VOTE_WINDOW()) + 1);
    vm.expectRevert(L2VoteAggregator.ProposalInactive.selector);
    voteAggregator.castVoteWithReason(_proposalId, _voteType, reason);
  }

  function testFuzz_RevertWhen_VoterHasAlreadyVoted(
    uint96 _amount,
    uint8 _support,
    string memory reason
  ) public {
    vm.assume(_amount != 0);
    vm.assume(_support < 3);
    L2VoteAggregator.VoteType _voteType = L2VoteAggregator.VoteType(_support);

    l2Erc20.mint(address(this), _amount);

    L2GovernorMetadata.Proposal memory l2Proposal = voteAggregator.createProposal(1, 3000, false);

    vm.roll(l2Proposal.voteStart + 1);
    voteAggregator.castVoteWithReason(1, _voteType, reason);

    vm.expectRevert("L2CountingFractional: all weight cast");
    voteAggregator.castVoteWithReason(1, _voteType, reason);
  }

  function testFuzz_RevertWhen_VoterHasNoWeight(
    uint96 _amount,
    uint8 _support,
    string memory reason
  ) public {
    vm.assume(_amount != 0);
    vm.assume(_support < 3);
    L2VoteAggregator.VoteType _voteType = L2VoteAggregator.VoteType(_support);

    L2GovernorMetadata.Proposal memory l2Proposal = voteAggregator.createProposal(1, 3000, false);

    vm.roll(l2Proposal.voteStart + 1);
    vm.expectRevert(L2VoteAggregator.NoWeight.selector);
    voteAggregator.castVoteWithReason(1, _voteType, reason);
  }

  function testFuzz_CorrectlyCastVoteAgainst(uint96 _amount, string memory reason) public {
    vm.assume(_amount != 0);
    l2Erc20.mint(address(this), _amount);

    L2GovernorMetadata.Proposal memory l2Proposal = voteAggregator.createProposal(1, 3000, false);

    vm.roll(l2Proposal.voteStart + 1);
    vm.expectEmit();
    emit VoteCast(address(this), 1, 0, _amount, reason);

    voteAggregator.castVoteWithReason(1, L2VoteAggregator.VoteType.Against, reason);
    (uint256 against,,) = voteAggregator.proposalVotes(1);
    assertEq(against, _amount, "Votes against is not correct");
  }

  function testFuzz_CorrectlyCastVoteAbstain(uint96 _amount, string memory reason) public {
    vm.assume(_amount != 0);
    l2Erc20.mint(address(this), _amount);

    L2GovernorMetadata.Proposal memory l2Proposal = voteAggregator.createProposal(1, 3000, false);

    vm.roll(l2Proposal.voteStart + 1);
    vm.expectEmit();
    emit VoteCast(address(this), 1, 2, _amount, reason);

    voteAggregator.castVoteWithReason(1, L2VoteAggregator.VoteType.Abstain, reason);
    (,, uint256 abstain) = voteAggregator.proposalVotes(1);

    assertEq(abstain, _amount, "Votes abstain is not correct");
  }

  function testFuzz_CorrectlyCastVoteFor(uint96 _amount, string memory reason) public {
    vm.assume(_amount != 0);
    l2Erc20.mint(address(this), _amount);

    L2GovernorMetadata.Proposal memory l2Proposal = voteAggregator.createProposal(1, 3000, false);

    vm.roll(l2Proposal.voteStart + 1);
    vm.expectEmit();
    emit VoteCast(address(this), 1, 1, _amount, reason);

    voteAggregator.castVoteWithReason(1, L2VoteAggregator.VoteType.For, reason);
    (, uint256 forVotes,) = voteAggregator.proposalVotes(1);

    assertEq(forVotes, _amount, "Votes for is not correct");
  }
}

contract CastVoteWithReasonAndParams is L2VoteAggregatorTest {
  function testFuzz_RevertWhen_BeforeProposalStart(
    uint40 againstVotes,
    uint40 forVotes,
    uint40 abstainVotes,
    string memory reason
  ) public {
    uint128 amount = uint128(againstVotes) + forVotes + abstainVotes;
    bytes memory voteData = abi.encodePacked(againstVotes, forVotes, abstainVotes);
    voteAggregator.createProposal(1, 3000, false);

    l2Erc20.mint(address(this), amount);

    vm.roll(block.number - 1);
    vm.expectRevert(L2VoteAggregator.ProposalInactive.selector);
    voteAggregator.castVoteWithReasonAndParams(1, 1, reason, voteData);
  }

  function testFuzz_RevertWhen_ProposalCanceled(
    uint256 _proposalId,
    uint40 againstVotes,
    uint40 forVotes,
    uint40 abstainVotes,
    string memory reason
  ) public {
    uint128 amount = uint128(againstVotes) + forVotes + abstainVotes;
    bytes memory voteData = abi.encodePacked(againstVotes, forVotes, abstainVotes);

    vm.assume(amount != 0);
    l2Erc20.mint(address(this), amount);

    // In the setup we use a mock contract rather than the actual contract
    L2GovernorMetadata.Proposal memory l2Proposal =
      voteAggregator.createProposal(_proposalId, 1200, true);

    vm.roll(l2Proposal.voteStart + 1);
    vm.expectRevert(L2VoteAggregator.ProposalInactive.selector);
    voteAggregator.castVoteWithReasonAndParams(_proposalId, 1, reason, voteData);
  }

  function testFuzz_RevertWhen_AfterCastWindow(
    uint256 _proposalId,
    uint64 _proposalDuration,
    uint40 againstVotes,
    uint40 forVotes,
    uint40 abstainVotes,
    string memory reason
  ) public {
    uint128 amount = uint128(againstVotes) + forVotes + abstainVotes;
    bytes memory voteData = abi.encodePacked(againstVotes, forVotes, abstainVotes);

    _proposalDuration = uint64(
      bound(_proposalDuration, voteAggregator.CAST_VOTE_WINDOW(), type(uint64).max - block.number)
    );

    // In the setup we use a mock contract rather than the actual contract
    L2GovernorMetadata.Proposal memory l2Proposal =
      voteAggregator.createProposal(_proposalId, _proposalDuration);

    vm.roll(l2Proposal.voteStart - 1);
    l2Erc20.mint(address(this), amount);

    // Our active check is inclusive so we need to add 1
    vm.roll(l2Proposal.voteStart + (_proposalDuration - voteAggregator.CAST_VOTE_WINDOW()) + 1);
    vm.expectRevert(L2VoteAggregator.ProposalInactive.selector);
    voteAggregator.castVoteWithReasonAndParams(_proposalId, 1, reason, voteData);
  }

  function testFuzz_RevertWhen_VoterHasNoWeight(
    uint40 againstVotes,
    uint40 forVotes,
    uint40 abstainVotes,
    string memory reason
  ) public {
    bytes memory voteData = abi.encodePacked(againstVotes, forVotes, abstainVotes);

    L2GovernorMetadata.Proposal memory l2Proposal = voteAggregator.createProposal(1, 3000, false);

    vm.roll(l2Proposal.voteStart + 1);
    vm.expectRevert(L2VoteAggregator.NoWeight.selector);
    voteAggregator.castVoteWithReasonAndParams(1, 1, reason, voteData);
  }

  function testFuzz_CorrectlyVoteAgain(
    uint40 againstVotes,
    uint40 forVotes,
    uint40 abstainVotes,
    string memory reason
  ) public {
    uint128 amount = uint128(againstVotes) + forVotes + abstainVotes;
    vm.assume(againstVotes != 0);
    vm.assume(abstainVotes != 0);
    bytes memory firstVoteData =
      abi.encodePacked(uint128(againstVotes), uint128(forVotes), uint128(0));
    bytes memory secondVoteData = abi.encodePacked(uint128(0), uint128(0), uint128(abstainVotes));

    l2Erc20.mint(address(this), amount);

    L2GovernorMetadata.Proposal memory l2Proposal = voteAggregator.createProposal(1, 3000, false);

    vm.roll(l2Proposal.voteStart + 1);
    voteAggregator.castVoteWithReasonAndParams(1, 1, reason, firstVoteData);

    (uint256 againstFirst, uint256 inFavorFirst, uint256 abstainFirst) =
      voteAggregator.proposalVotes(1);
    assertEq(againstFirst, againstVotes, "First against votes for is not correct");
    assertEq(inFavorFirst, forVotes, "First inFavor votes for is not correct");
    assertEq(abstainFirst, 0, "First abstain votes for is not correct");

    voteAggregator.castVoteWithReasonAndParams(1, 1, reason, secondVoteData);

    (uint256 againstSecond, uint256 inFavorSecond, uint256 abstainSecond) =
      voteAggregator.proposalVotes(1);
    assertEq(againstSecond, againstVotes, "Second against votes for is not correct");
    assertEq(inFavorSecond, forVotes, "Second inFavor votes for is not correct");
    assertEq(abstainSecond, abstainVotes, "Second abstain votes for is not correct");
  }

  function testFuzz_CorrectlyCastVote(
    uint40 againstVotes,
    uint40 forVotes,
    uint40 abstainVotes,
    string memory reason
  ) public {
    uint128 amount = uint128(againstVotes) + forVotes + abstainVotes;
    bytes memory voteData =
      abi.encodePacked(uint128(againstVotes), uint128(forVotes), uint128(abstainVotes));
    vm.assume(amount != 0);
    l2Erc20.mint(address(this), amount);

    L2GovernorMetadata.Proposal memory l2Proposal = voteAggregator.createProposal(1, 3000, false);

    vm.roll(l2Proposal.voteStart + 1);
    vm.expectEmit();
    emit VoteCastWithParams(address(this), 1, 1, amount, reason, voteData);

    voteAggregator.castVoteWithReasonAndParams(1, 1, reason, voteData);
    (uint256 against, uint256 inFavor, uint256 abstain) = voteAggregator.proposalVotes(1);

    assertEq(against, againstVotes, "Against votes for is not correct");
    assertEq(inFavor, forVotes, "inFavor votes for is not correct");
    assertEq(abstain, abstainVotes, "Abstain votes for is not correct");
  }
}

contract CastVoteBySig is L2VoteAggregatorTest {
  function _signVoteMessage(uint256 _proposalId, uint8 _support)
    internal
    view
    returns (uint8, bytes32, bytes32)
  {
    bytes32 _voteMessage = keccak256(
      abi.encode(keccak256("Ballot(uint256 proposalId,uint8 support)"), _proposalId, _support)
    );

    bytes32 _voteMessageHash = keccak256(
      abi.encodePacked("\x19\x01", voteAggregator.exposed_domainSeparatorV4(), _voteMessage)
    );

    return vm.sign(privateKey, _voteMessageHash);
  }

  function testFuzz_RevertWhen_BeforeProposalStart(
    uint256 _proposalId,
    uint96 _amount,
    uint8 _support
  ) public {
    vm.assume(_support < 3);
    L2VoteAggregator.VoteType _voteType = L2VoteAggregator.VoteType(_support);

    voteAggregator.createProposal(1, 3000, false);

    l2Erc20.mint(address(this), _amount);

    (uint8 _v, bytes32 _r, bytes32 _s) = _signVoteMessage(_proposalId, _support);

    vm.roll(block.number - 1);
    vm.expectRevert(L2VoteAggregator.ProposalInactive.selector);
    voteAggregator.castVoteBySig(1, _voteType, _v, _r, _s);
  }

  function testFuzz_RevertWhen_ProposalCanceled(uint96 _amount, uint8 _support, uint256 _proposalId)
    public
  {
    vm.assume(_amount != 0);
    vm.assume(_support < 3);
    L2VoteAggregator.VoteType _voteType = L2VoteAggregator.VoteType(_support);
    l2Erc20.mint(address(this), _amount);

    // In the setup we use a mock contract rather than the actual contract
    L2GovernorMetadata.Proposal memory l2Proposal =
      voteAggregator.createProposal(_proposalId, 1200, true);

    (uint8 _v, bytes32 _r, bytes32 _s) = _signVoteMessage(_proposalId, _support);

    vm.roll(l2Proposal.voteStart + 1);
    vm.expectRevert(L2VoteAggregator.ProposalInactive.selector);
    voteAggregator.castVoteBySig(_proposalId, _voteType, _v, _r, _s);
  }

  function testFuzz_RevertWhen_AfterCastWindow(
    uint96 _amount,
    uint8 _support,
    uint256 _proposalId,
    uint64 _proposalDuration
  ) public {
    vm.assume(_amount != 0);
    vm.assume(_support < 3);
    L2VoteAggregator.VoteType _voteType = L2VoteAggregator.VoteType(_support);

    _proposalDuration = uint64(
      bound(_proposalDuration, voteAggregator.CAST_VOTE_WINDOW(), type(uint64).max - block.number)
    );

    // In the setup we use a mock contract rather than the actual contract
    L2GovernorMetadata.Proposal memory l2Proposal =
      voteAggregator.createProposal(_proposalId, _proposalDuration);

    vm.roll(l2Proposal.voteStart - 1);
    l2Erc20.mint(address(this), _amount);

    (uint8 _v, bytes32 _r, bytes32 _s) = _signVoteMessage(_proposalId, _support);
    // Our active check is inclusive so we need to add 1
    vm.roll(l2Proposal.voteStart + (_proposalDuration - voteAggregator.CAST_VOTE_WINDOW()) + 1);
    vm.expectRevert(L2VoteAggregator.ProposalInactive.selector);
    voteAggregator.castVoteBySig(_proposalId, _voteType, _v, _r, _s);
  }

  function testFuzz_RevertWhen_VoterHasAlreadyVoted(uint96 _amount, uint8 _support) public {
    vm.assume(_amount != 0);
    vm.assume(_support < 3);
    L2VoteAggregator.VoteType _voteType = L2VoteAggregator.VoteType(_support);
    uint256 proposalId = 1;

    vm.prank(voterAddress);
    l2Erc20.mint(voterAddress, _amount);

    L2GovernorMetadata.Proposal memory l2Proposal = voteAggregator.createProposal(1, 3000, false);

    (uint8 _v, bytes32 _r, bytes32 _s) = _signVoteMessage(proposalId, _support);

    vm.roll(l2Proposal.voteStart + 1);
    voteAggregator.castVoteBySig(proposalId, _voteType, _v, _r, _s);

    vm.expectRevert("L2CountingFractional: all weight cast");
    voteAggregator.castVoteBySig(proposalId, _voteType, _v, _r, _s);
  }

  function testFuzz_RevertWhen_VoterHasNoWeight(uint96 _amount, uint8 _support) public {
    vm.assume(_amount != 0);
    vm.assume(_support < 3);
    uint256 proposalId = 1;
    L2VoteAggregator.VoteType _voteType = L2VoteAggregator.VoteType(_support);

    L2GovernorMetadata.Proposal memory l2Proposal =
      voteAggregator.createProposal(proposalId, 3000, false);

    (uint8 _v, bytes32 _r, bytes32 _s) = _signVoteMessage(proposalId, _support);

    vm.roll(l2Proposal.voteStart + 1);
    vm.expectRevert(L2VoteAggregator.NoWeight.selector);
    voteAggregator.castVoteBySig(proposalId, _voteType, _v, _r, _s);
  }

  function testFuzz_CorrectlyCastVoteAgainst(uint96 _amount) public {
    vm.assume(_amount != 0);
    vm.prank(voterAddress);
    l2Erc20.mint(voterAddress, _amount);
    uint256 proposalId = 1;
    L2VoteAggregator.VoteType _voteType = L2VoteAggregator.VoteType.Against;

    L2GovernorMetadata.Proposal memory l2Proposal = voteAggregator.createProposal(1, 3000, false);

    vm.roll(l2Proposal.voteStart + 1);

    (uint8 _v, bytes32 _r, bytes32 _s) = _signVoteMessage(proposalId, uint8(_voteType));

    vm.expectEmit();
    emit VoteCast(voterAddress, proposalId, 0, _amount, "");

    voteAggregator.castVoteBySig(proposalId, _voteType, _v, _r, _s);
    (uint256 against,,) = voteAggregator.proposalVotes(proposalId);
    assertEq(against, _amount, "Votes against is not correct");
  }

  function testFuzz_CorrectlyCastVoteAbstain(uint96 _amount) public {
    vm.assume(_amount != 0);

    uint256 proposalId = 1;
    L2VoteAggregator.VoteType _voteType = L2VoteAggregator.VoteType.Abstain;

    vm.prank(voterAddress);
    l2Erc20.mint(voterAddress, _amount);

    L2GovernorMetadata.Proposal memory l2Proposal = voteAggregator.createProposal(1, 3000, false);

    vm.roll(l2Proposal.voteStart + 1);

    (uint8 _v, bytes32 _r, bytes32 _s) = _signVoteMessage(proposalId, uint8(_voteType));

    vm.expectEmit();
    emit VoteCast(voterAddress, proposalId, 2, _amount, "");

    voteAggregator.castVoteBySig(proposalId, _voteType, _v, _r, _s);
    (,, uint256 abstain) = voteAggregator.proposalVotes(proposalId);

    assertEq(abstain, _amount, "Votes abstain is not correct");
  }

  function testFuzz_CorrectlyCastVoteFor(uint96 _amount) public {
    vm.assume(_amount != 0);

    uint256 proposalId = 1;
    L2VoteAggregator.VoteType _voteType = L2VoteAggregator.VoteType.For;

    vm.prank(voterAddress);
    l2Erc20.mint(voterAddress, _amount);

    L2GovernorMetadata.Proposal memory l2Proposal = voteAggregator.createProposal(1, 3000, false);

    vm.roll(l2Proposal.voteStart + 1);
    vm.expectEmit();
    emit VoteCast(voterAddress, 1, 1, _amount, "");

    (uint8 _v, bytes32 _r, bytes32 _s) = _signVoteMessage(proposalId, uint8(_voteType));

    voteAggregator.castVoteBySig(1, _voteType, _v, _r, _s);
    (, uint256 forVotes,) = voteAggregator.proposalVotes(1);

    assertEq(forVotes, _amount, "Votes for is not correct");
  }
}

contract _CastVote is L2VoteAggregatorTest {
  function testFuzz_RevertWhen_BeforeProposalStart(uint96 _amount, uint8 _support) public {
    vm.assume(_support < 3);
    L2VoteAggregator.VoteType _voteType = L2VoteAggregator.VoteType(_support);

    voteAggregator.createProposal(1, 3000, false);

    l2Erc20.mint(address(this), _amount);

    vm.roll(block.number - 1);
    vm.expectRevert(L2VoteAggregator.ProposalInactive.selector);
    voteAggregator.exposed_castVote(1, address(this), _voteType, "");
  }

  function testFuzz_RevertWhen_ProposalCanceled(uint96 _amount, uint8 _support, uint256 _proposalId)
    public
  {
    vm.assume(_amount != 0);
    vm.assume(_support < 3);
    L2VoteAggregator.VoteType _voteType = L2VoteAggregator.VoteType(_support);
    l2Erc20.mint(address(this), _amount);

    // In the setup we use a mock contract rather than the actual contract
    L2GovernorMetadata.Proposal memory l2Proposal =
      voteAggregator.createProposal(_proposalId, 1200, true);

    vm.roll(l2Proposal.voteStart + 1);
    vm.expectRevert(L2VoteAggregator.ProposalInactive.selector);
    voteAggregator.exposed_castVote(_proposalId, address(this), _voteType, "");
  }

  function testFuzz_RevertWhen_AfterCastWindow(
    uint96 _amount,
    uint8 _support,
    uint256 _proposalId,
    uint64 _proposalDuration
  ) public {
    vm.assume(_amount != 0);
    vm.assume(_support < 3);
    L2VoteAggregator.VoteType _voteType = L2VoteAggregator.VoteType(_support);

    _proposalDuration = uint64(
      bound(_proposalDuration, voteAggregator.CAST_VOTE_WINDOW(), type(uint64).max - block.number)
    );

    // In the setup we use a mock contract rather than the actual contract
    L2GovernorMetadata.Proposal memory l2Proposal =
      voteAggregator.createProposal(_proposalId, _proposalDuration);

    vm.roll(l2Proposal.voteStart - 1);
    l2Erc20.mint(address(this), _amount);

    // Our active check is inclusive so we need to add 1
    vm.roll(l2Proposal.voteStart + (_proposalDuration - voteAggregator.CAST_VOTE_WINDOW()) + 1);
    vm.expectRevert(L2VoteAggregator.ProposalInactive.selector);
    voteAggregator.exposed_castVote(_proposalId, address(this), _voteType, "");
  }

  function testFuzz_RevertWhen_VoterHasAlreadyVoted(uint96 _amount, uint8 _support) public {
    vm.assume(_amount != 0);
    vm.assume(_support < 3);
    L2VoteAggregator.VoteType _voteType = L2VoteAggregator.VoteType(_support);

    l2Erc20.mint(address(this), _amount);

    L2GovernorMetadata.Proposal memory l2Proposal = voteAggregator.createProposal(1, 3000, false);

    vm.roll(l2Proposal.voteStart + 1);
    voteAggregator.exposed_castVote(1, address(this), _voteType, "");

    vm.expectRevert("L2CountingFractional: all weight cast");
    voteAggregator.exposed_castVote(1, address(this), _voteType, "");
  }

  function testFuzz_RevertWhen_VoterHasNoWeight(uint96 _amount, uint8 _support) public {
    vm.assume(_amount != 0);
    vm.assume(_support < 3);
    L2VoteAggregator.VoteType _voteType = L2VoteAggregator.VoteType(_support);

    L2GovernorMetadata.Proposal memory l2Proposal = voteAggregator.createProposal(1, 3000, false);

    vm.roll(l2Proposal.voteStart + 1);
    vm.expectRevert(L2VoteAggregator.NoWeight.selector);
    voteAggregator.exposed_castVote(1, address(this), _voteType, "");
  }

  function testFuzz_CorrectlyCastVoteAgainst(uint96 _amount) public {
    vm.assume(_amount != 0);
    l2Erc20.mint(address(this), _amount);

    L2GovernorMetadata.Proposal memory l2Proposal = voteAggregator.createProposal(1, 3000, false);

    vm.roll(l2Proposal.voteStart + 1);
    vm.expectEmit();
    emit VoteCast(address(this), 1, 0, _amount, "");

    voteAggregator.exposed_castVote(1, address(this), L2VoteAggregator.VoteType.Against, "");
    (uint256 against,,) = voteAggregator.proposalVotes(1);
    assertEq(against, _amount, "Votes against is not correct");
  }

  function testFuzz_CorrectlyCastVoteAbstain(uint96 _amount) public {
    vm.assume(_amount != 0);
    l2Erc20.mint(address(this), _amount);

    L2GovernorMetadata.Proposal memory l2Proposal = voteAggregator.createProposal(1, 3000, false);

    vm.roll(l2Proposal.voteStart + 1);
    vm.expectEmit();
    emit VoteCast(address(this), 1, 2, _amount, "");

    voteAggregator.exposed_castVote(1, address(this), L2VoteAggregator.VoteType.Abstain, "");
    (,, uint256 abstain) = voteAggregator.proposalVotes(1);

    assertEq(abstain, _amount, "Votes abstain is not correct");
  }

  function testFuzz_CorrectlyCastVoteFor(uint96 _amount) public {
    vm.assume(_amount != 0);
    l2Erc20.mint(address(this), _amount);

    L2GovernorMetadata.Proposal memory l2Proposal = voteAggregator.createProposal(1, 3000, false);

    vm.roll(l2Proposal.voteStart + 1);
    vm.expectEmit();
    emit VoteCast(address(this), 1, 1, _amount, "");

    voteAggregator.exposed_castVote(1, address(this), L2VoteAggregator.VoteType.For, "");
    (, uint256 forVotes,) = voteAggregator.proposalVotes(1);

    assertEq(forVotes, _amount, "Votes for is not correct");
  }
}

contract Propose is L2VoteAggregatorTest {
  function testFuzz_RevertIf_Called(
    address[] memory addrs,
    uint256[] memory exam,
    bytes[] memory te,
    string memory hi
  ) public {
    vm.expectRevert(L2VoteAggregator.UnsupportedMethod.selector);
    voteAggregator.propose(addrs, exam, te, hi);
  }
}

contract Execute is L2VoteAggregatorTest {
  function testFuzz_RevertIf_Called(
    address[] memory addrs,
    uint256[] memory exam,
    bytes[] memory te,
    bytes32 hi
  ) public {
    vm.expectRevert(L2VoteAggregator.UnsupportedMethod.selector);
    voteAggregator.execute(addrs, exam, te, hi);
  }
}

contract InternalVotingPeriodEnd is L2VoteAggregatorTest {
  function testFuzz_CorrectlyCalculateInternalVotingPeriod(
    uint256 proposalId,
    uint256 voteStart,
    uint256 voteEnd,
    bool isCanceled
  ) public {
    voteEnd = bound(voteEnd, voteAggregator.CAST_VOTE_WINDOW(), type(uint256).max);
    L2GovernorMetadata.Proposal memory proposal =
      voteAggregator.createProposal(proposalId, voteStart, voteEnd, isCanceled);

    uint256 lastVotingBlock = voteAggregator.internalVotingPeriodEnd(proposalId);
    assertEq(lastVotingBlock, proposal.voteEnd - voteAggregator.CAST_VOTE_WINDOW());
  }
}

contract ProposalVoteActive is L2VoteAggregatorTest {
  function testFuzz_ProposalVoteIsActive(uint256 proposalId, uint64 voteStart, uint64 voteEnd)
    public
  {
    voteStart = uint64(bound(voteStart, 0, block.number));
    voteEnd =
      uint64(bound(voteEnd, block.number + voteAggregator.CAST_VOTE_WINDOW(), type(uint64).max));
    voteAggregator.createProposal(proposalId, voteStart, voteEnd, false);

    uint256 lastVotingBlock = voteAggregator.internalVotingPeriodEnd(proposalId);

    vm.roll(lastVotingBlock);
    bool active = voteAggregator.proposalVoteActive(proposalId);
    assertEq(active, true, "Proposal is supposed to be active");
  }

  function testFuzz_ProposalVoteIsInactiveBefore(
    uint256 proposalId,
    uint64 voteStart,
    uint64 voteEnd,
    bool isCanceled
  ) public {
    vm.assume(voteStart > 0); // Prevent underflow because we subtract 1
    vm.assume(voteStart > block.number); // Block number must be greater than vote start
    vm.assume(voteEnd > voteAggregator.CAST_VOTE_WINDOW()); //  Prevent underflow
    vm.assume(voteEnd - voteAggregator.CAST_VOTE_WINDOW() > voteStart); // Proposal must have a
      // voting
      // block before the cast
    voteAggregator.createProposal(proposalId, voteStart, voteEnd, isCanceled);

    bool active = voteAggregator.proposalVoteActive(proposalId);
    assertFalse(active, "Proposal is supposed to be inactive");
  }

  function testFuzz_ProposalVoteIsCanceled(uint256 proposalId, uint64 voteStart, uint64 voteEnd)
    public
  {
    vm.assume(voteStart > 0); // Prevent underflow because we subtract 1
    vm.assume(voteStart > block.number); // Block number must be greater than vote start
    vm.assume(voteEnd > voteAggregator.CAST_VOTE_WINDOW()); // Prevent underflow
    voteAggregator.createProposal(proposalId, voteStart, voteEnd, false);

    bool active = voteAggregator.proposalVoteActive(proposalId);
    assertFalse(active, "Proposal is supposed to be inactive");
  }
}

contract BridgeVote is L2VoteAggregatorTest {
  function testFuzz_CorrectlyBridgeVote(uint256 proposalId) public {
    voteAggregator.createProposal(proposalId, voteAggregator.CAST_VOTE_WINDOW());

    vm.expectEmit();
    emit VoteBridged(proposalId, 0, 0, 0);

    voteAggregator.bridgeVote(proposalId);
  }
}
