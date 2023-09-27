// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20VotesComp} from
  "openzeppelin-flexible-voting/governance/extensions/GovernorVotesComp.sol";
import {WormholeRelayerBasicTest} from "wormhole-solidity-sdk/testing/WormholeRelayerTest.sol";
import {Test} from "forge-std/Test.sol";

import {L1Block} from "src/L1Block.sol";
import {L2GovernorMetadata} from "src/L2GovernorMetadata.sol";
import {L2VoteAggregator} from "src/L2VoteAggregator.sol";
import {FakeERC20} from "src/FakeERC20.sol";

import {Constants} from "test/Constants.sol";
import {FakeERC20} from "src/FakeERC20.sol";
import {GovernorMetadataMock} from "test/mock/GovernorMetadataMock.sol";
import {L1VotePoolHarness} from "test/harness/L1VotePoolHarness.sol";
import {GovernorFlexibleVotingMock} from "test/mock/GovernorMock.sol";

contract L2VoteAggregatorHarness is L2VoteAggregator {
  constructor(address _votingToken, address _governorMetadata, address _l1BlockAddress)
    L2VoteAggregator(_votingToken, _governorMetadata, _l1BlockAddress)
  {}

  function _bridgeVote(bytes memory) internal override {}

  function exposed_castVote(uint256 proposalId, address voter, VoteType support, string memory reason) public returns (uint256) {
    return _castVote(proposalId, voter, support, reason);
  } 

  function exposed_domainSeparatorV4() public view returns (bytes32) {
    return _domainSeparatorV4();
  }
}

contract L2VoteAggregatorBase is Test, Constants {
  L2VoteAggregatorHarness voteAggregator;
  event VoteCast(address indexed voter, uint256 proposalId, uint8 support, uint256 weight, string reason);
  FakeERC20 l2Erc20;
  address voterAddress;
  uint256 privateKey;
  

  function setUp() public {
    (voterAddress, privateKey) = makeAddrAndKey("voter");
    GovernorMetadataMock l2GovernorMetadata = new GovernorMetadataMock(L2_CHAIN.wormholeRelayer);
    l2Erc20 = new FakeERC20("GovExample", "GOV");
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

contract CastVote is L2VoteAggregatorBase {
  function testFuzz_RevertWhen_BeforeProposalStart(uint96 _amount, uint8 _support) public {
    vm.assume(_support < 3);
    L2VoteAggregator.VoteType _voteType = L2VoteAggregator.VoteType(_support);

    l2Erc20.mint(address(this), _amount);

    vm.roll(block.number - 1);
    vm.expectRevert(L2VoteAggregator.ProposalInactive.selector);
    voteAggregator.castVote(1, _voteType);
  }

  function testFuzz_RevertWhen_ProposalCancelled(uint96 _amount, uint8 _support, uint256 _proposalId) public {
    vm.assume(_amount != 0);
    vm.assume(_support < 3);
    L2VoteAggregator.VoteType _voteType = L2VoteAggregator.VoteType(_support);
    l2Erc20.mint(address(this), _amount);

    // In the setup we use a mock contract rather than the actual contract
    L2GovernorMetadata.Proposal memory l2Proposal = GovernorMetadataMock(
      address(voteAggregator.GOVERNOR_METADATA())
    ).createProposal(_proposalId, 1200, true);

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
    L2GovernorMetadata.Proposal memory l2Proposal = GovernorMetadataMock(
      address(voteAggregator.GOVERNOR_METADATA())
    ).createProposal(_proposalId, _proposalDuration);

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

    L2GovernorMetadata.Proposal memory l2Proposal =
      voteAggregator.GOVERNOR_METADATA().getProposal(1);

    vm.roll(l2Proposal.voteStart + 1);
    voteAggregator.castVote(1, _voteType);

    vm.expectRevert(L2VoteAggregator.AlreadyVoted.selector);
    voteAggregator.castVote(1, _voteType);
  }

  function testFuzz_RevertWhen_VoterHasNoWeight(uint96 _amount, uint8 _support) public {
    vm.assume(_amount != 0);
    vm.assume(_support < 3);
    L2VoteAggregator.VoteType _voteType = L2VoteAggregator.VoteType(_support);

    L2GovernorMetadata.Proposal memory l2Proposal =
      voteAggregator.GOVERNOR_METADATA().getProposal(1);

    vm.roll(l2Proposal.voteStart + 1);
    vm.expectRevert(L2VoteAggregator.NoWeight.selector);
    voteAggregator.castVote(1, _voteType);
  }

  function testFuzz_CorrectlyCastVoteAgainst(uint96 _amount) public {
    vm.assume(_amount != 0);
    l2Erc20.mint(address(this), _amount);

    L2GovernorMetadata.Proposal memory l2Proposal =
      voteAggregator.GOVERNOR_METADATA().getProposal(1);

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

    L2GovernorMetadata.Proposal memory l2Proposal =
      voteAggregator.GOVERNOR_METADATA().getProposal(1);

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

    L2GovernorMetadata.Proposal memory l2Proposal =
      voteAggregator.GOVERNOR_METADATA().getProposal(1);

    vm.roll(l2Proposal.voteStart + 1);
    vm.expectEmit();
    emit VoteCast(address(this), 1, 1, _amount, "");

    voteAggregator.castVote(1, L2VoteAggregator.VoteType.For);
    (, uint256 forVotes,) = voteAggregator.proposalVotes(1);

    assertEq(forVotes, _amount, "Votes for is not correct");
  }
}

contract CastVoteWithReason is L2VoteAggregatorBase {
  function testFuzz_RevertWhen_BeforeProposalStart(uint96 _amount, uint8 _support, string memory reason) public {
    vm.assume(_support < 3);
    L2VoteAggregator.VoteType _voteType = L2VoteAggregator.VoteType(_support);

    l2Erc20.mint(address(this), _amount);

    vm.roll(block.number - 1);
    vm.expectRevert(L2VoteAggregator.ProposalInactive.selector);
    voteAggregator.castVoteWithReason(1, _voteType, reason);
  }

  function testFuzz_RevertWhen_ProposalCancelled(uint96 _amount, uint8 _support, uint256 _proposalId, string memory reason) public {
    vm.assume(_amount != 0);
    vm.assume(_support < 3);
    L2VoteAggregator.VoteType _voteType = L2VoteAggregator.VoteType(_support);
    l2Erc20.mint(address(this), _amount);

    // In the setup we use a mock contract rather than the actual contract
    L2GovernorMetadata.Proposal memory l2Proposal = GovernorMetadataMock(
      address(voteAggregator.GOVERNOR_METADATA())
    ).createProposal(_proposalId, 1200, true);

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
    L2GovernorMetadata.Proposal memory l2Proposal = GovernorMetadataMock(
      address(voteAggregator.GOVERNOR_METADATA())
    ).createProposal(_proposalId, _proposalDuration);

    vm.roll(l2Proposal.voteStart - 1);
    l2Erc20.mint(address(this), _amount);

    // Our active check is inclusive so we need to add 1
    vm.roll(l2Proposal.voteStart + (_proposalDuration - voteAggregator.CAST_VOTE_WINDOW()) + 1);
    vm.expectRevert(L2VoteAggregator.ProposalInactive.selector);
    voteAggregator.castVoteWithReason(_proposalId, _voteType, reason);
  }

  function testFuzz_RevertWhen_VoterHasAlreadyVoted(uint96 _amount, uint8 _support, string memory reason) public {
    vm.assume(_amount != 0);
    vm.assume(_support < 3);
    L2VoteAggregator.VoteType _voteType = L2VoteAggregator.VoteType(_support);

    l2Erc20.mint(address(this), _amount);

    L2GovernorMetadata.Proposal memory l2Proposal =
      voteAggregator.GOVERNOR_METADATA().getProposal(1);

    vm.roll(l2Proposal.voteStart + 1);
    voteAggregator.castVoteWithReason(1, _voteType, reason);

    vm.expectRevert(L2VoteAggregator.AlreadyVoted.selector);
    voteAggregator.castVoteWithReason(1, _voteType, reason);
  }

  function testFuzz_RevertWhen_VoterHasNoWeight(uint96 _amount, uint8 _support, string memory reason) public {
    vm.assume(_amount != 0);
    vm.assume(_support < 3);
    L2VoteAggregator.VoteType _voteType = L2VoteAggregator.VoteType(_support);

    L2GovernorMetadata.Proposal memory l2Proposal =
      voteAggregator.GOVERNOR_METADATA().getProposal(1);

    vm.roll(l2Proposal.voteStart + 1);
    vm.expectRevert(L2VoteAggregator.NoWeight.selector);
    voteAggregator.castVoteWithReason(1, _voteType, reason);
  }

  function testFuzz_CorrectlyCastVoteAgainst(uint96 _amount, string memory reason) public {
    vm.assume(_amount != 0);
    l2Erc20.mint(address(this), _amount);

    L2GovernorMetadata.Proposal memory l2Proposal =
      voteAggregator.GOVERNOR_METADATA().getProposal(1);

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

    L2GovernorMetadata.Proposal memory l2Proposal =
      voteAggregator.GOVERNOR_METADATA().getProposal(1);

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

    L2GovernorMetadata.Proposal memory l2Proposal =
      voteAggregator.GOVERNOR_METADATA().getProposal(1);

    vm.roll(l2Proposal.voteStart + 1);
    vm.expectEmit();
    emit VoteCast(address(this), 1, 1, _amount, reason);

    voteAggregator.castVoteWithReason(1, L2VoteAggregator.VoteType.For, reason);
    (, uint256 forVotes,) = voteAggregator.proposalVotes(1);

    assertEq(forVotes, _amount, "Votes for is not correct");
  }
}

contract CastVoteBySig is L2VoteAggregatorBase {
  function _signVoteMessage(uint256 _proposalId, uint8 _support) internal view returns (uint8, bytes32, bytes32) {
    bytes32 _voteMessage = keccak256(
      abi.encode(
        keccak256("Ballot(uint256 proposalId,uint8 support)"),
        _proposalId,
        _support
      )
    );

    bytes32 _voteMessageHash =
      keccak256(abi.encodePacked("\x19\x01", voteAggregator.exposed_domainSeparatorV4(), _voteMessage));

    return vm.sign(privateKey, _voteMessageHash);
  }

  function testFuzz_RevertWhen_BeforeProposalStart(uint256 _proposalId, uint96 _amount, uint8 _support) public {
    vm.assume(_support < 3);
    L2VoteAggregator.VoteType _voteType = L2VoteAggregator.VoteType(_support);

    l2Erc20.mint(address(this), _amount);

    (uint8 _v, bytes32 _r, bytes32 _s) = _signVoteMessage(_proposalId, _support);

    vm.roll(block.number - 1);
    vm.expectRevert(L2VoteAggregator.ProposalInactive.selector);
    voteAggregator.castVoteBySig(1, _voteType, _v, _r, _s);
  }

  function testFuzz_RevertWhen_ProposalCancelled(uint96 _amount, uint8 _support, uint256 _proposalId) public {
    vm.assume(_amount != 0);
    vm.assume(_support < 3);
    L2VoteAggregator.VoteType _voteType = L2VoteAggregator.VoteType(_support);
    l2Erc20.mint(address(this), _amount);

    // In the setup we use a mock contract rather than the actual contract
    L2GovernorMetadata.Proposal memory l2Proposal = GovernorMetadataMock(
      address(voteAggregator.GOVERNOR_METADATA())
    ).createProposal(_proposalId, 1200, true);

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
    L2GovernorMetadata.Proposal memory l2Proposal = GovernorMetadataMock(
      address(voteAggregator.GOVERNOR_METADATA())
    ).createProposal(_proposalId, _proposalDuration);

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

    L2GovernorMetadata.Proposal memory l2Proposal =
      voteAggregator.GOVERNOR_METADATA().getProposal(1);

    (uint8 _v, bytes32 _r, bytes32 _s) = _signVoteMessage(proposalId, _support);

    vm.roll(l2Proposal.voteStart + 1);
    voteAggregator.castVoteBySig(proposalId, _voteType, _v, _r, _s);

    vm.expectRevert(L2VoteAggregator.AlreadyVoted.selector);
    voteAggregator.castVoteBySig(proposalId, _voteType, _v, _r, _s);
  }

  function testFuzz_RevertWhen_VoterHasNoWeight(uint96 _amount, uint8 _support) public {
    vm.assume(_amount != 0);
    vm.assume(_support < 3);
    uint256 proposalId = 1;
    L2VoteAggregator.VoteType _voteType = L2VoteAggregator.VoteType(_support);

    L2GovernorMetadata.Proposal memory l2Proposal =
      voteAggregator.GOVERNOR_METADATA().getProposal(1);

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

    L2GovernorMetadata.Proposal memory l2Proposal =
      voteAggregator.GOVERNOR_METADATA().getProposal(1);

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

    l2Erc20.mint(voterAddress, _amount);

    L2GovernorMetadata.Proposal memory l2Proposal =
      voteAggregator.GOVERNOR_METADATA().getProposal(proposalId);

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

    L2GovernorMetadata.Proposal memory l2Proposal =
      voteAggregator.GOVERNOR_METADATA().getProposal(1);

    vm.roll(l2Proposal.voteStart + 1);
    vm.expectEmit();
    emit VoteCast(voterAddress, 1, 1, _amount, "");

    (uint8 _v, bytes32 _r, bytes32 _s) = _signVoteMessage(proposalId, uint8(_voteType));

    voteAggregator.castVoteWithReason(1, _voteType, _v, _r, _s);
    (, uint256 forVotes,) = voteAggregator.proposalVotes(1);

    assertEq(forVotes, _amount, "Votes for is not correct");
  }
}



contract _CastVote is L2VoteAggregatorBase {
  function testFuzz_RevertWhen_BeforeProposalStart(uint96 _amount, uint8 _support) public {
    vm.assume(_support < 3);
    L2VoteAggregator.VoteType _voteType = L2VoteAggregator.VoteType(_support);

    l2Erc20.mint(address(this), _amount);

    vm.roll(block.number - 1);
    vm.expectRevert(L2VoteAggregator.ProposalInactive.selector);
    voteAggregator.exposed_castVote(1, address(this), _voteType, "");
  }

  function testFuzz_RevertWhen_ProposalCancelled(uint96 _amount, uint8 _support, uint256 _proposalId) public {
    vm.assume(_amount != 0);
    vm.assume(_support < 3);
    L2VoteAggregator.VoteType _voteType = L2VoteAggregator.VoteType(_support);
    l2Erc20.mint(address(this), _amount);

    // In the setup we use a mock contract rather than the actual contract
    L2GovernorMetadata.Proposal memory l2Proposal = GovernorMetadataMock(
      address(voteAggregator.GOVERNOR_METADATA())
    ).createProposal(_proposalId, 1200, true);

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
    L2GovernorMetadata.Proposal memory l2Proposal = GovernorMetadataMock(
      address(voteAggregator.GOVERNOR_METADATA())
    ).createProposal(_proposalId, _proposalDuration);

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

    L2GovernorMetadata.Proposal memory l2Proposal =
      voteAggregator.GOVERNOR_METADATA().getProposal(1);

    vm.roll(l2Proposal.voteStart + 1);
    voteAggregator.exposed_castVote(1, address(this), _voteType, "");

    vm.expectRevert(L2VoteAggregator.AlreadyVoted.selector);
    voteAggregator.exposed_castVote(1, address(this), _voteType, "");
  }

  function testFuzz_RevertWhen_VoterHasNoWeight(uint96 _amount, uint8 _support) public {
    vm.assume(_amount != 0);
    vm.assume(_support < 3);
    L2VoteAggregator.VoteType _voteType = L2VoteAggregator.VoteType(_support);

    L2GovernorMetadata.Proposal memory l2Proposal =
      voteAggregator.GOVERNOR_METADATA().getProposal(1);

    vm.roll(l2Proposal.voteStart + 1);
    vm.expectRevert(L2VoteAggregator.NoWeight.selector);
    voteAggregator.exposed_castVote(1, address(this), _voteType, "");
  }

  function testFuzz_CorrectlyCastVoteAgainst(uint96 _amount) public {
    vm.assume(_amount != 0);
    l2Erc20.mint(address(this), _amount);

    L2GovernorMetadata.Proposal memory l2Proposal =
      voteAggregator.GOVERNOR_METADATA().getProposal(1);

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

    L2GovernorMetadata.Proposal memory l2Proposal =
      voteAggregator.GOVERNOR_METADATA().getProposal(1);

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

    L2GovernorMetadata.Proposal memory l2Proposal =
      voteAggregator.GOVERNOR_METADATA().getProposal(1);

    vm.roll(l2Proposal.voteStart + 1);
    vm.expectEmit();
    emit VoteCast(address(this), 1, 1, _amount, "");

    voteAggregator.exposed_castVote(1, address(this), L2VoteAggregator.VoteType.For, "");
    (, uint256 forVotes,) = voteAggregator.proposalVotes(1);

    assertEq(forVotes, _amount, "Votes for is not correct");
  }
}


// castVoteWithReason
// castVoteBySig

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

