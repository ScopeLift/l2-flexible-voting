// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {L1Block} from "src/L1Block.sol";
import {WormholeL2VoteAggregatorCalldataCompressor} from
  "src/optimized/WormholeL2VoteAggregatorCalldataCompressor.sol";
import {WormholeL2VoteAggregator} from "src/WormholeL2VoteAggregator.sol";
import {FakeERC20} from "src/FakeERC20.sol";
import {WormholeL2ERC20} from "src/WormholeL2ERC20.sol";
import {
  GovernorMetadataOptimizedMock, GovernorMetadataMock
} from "test/mock/GovernorMetadataMock.sol";
import {L2GovernorMetadata} from "src/L2GovernorMetadata.sol";
import {L2VoteAggregator} from "src/L2VoteAggregator.sol";
import {TestConstants} from "test/Constants.sol";
import {GovernorMetadataMockBase} from "test/mock/GovernorMetadataMock.sol";

// Use this is the sig tests
contract WormholeL2VoteAggregatorCalldataCompressorHarness is
  WormholeL2VoteAggregatorCalldataCompressor,
  GovernorMetadataMockBase
{
  constructor(
    address _votingToken,
    address _relayer,
    address _l1BlockAddress,
    uint16 _sourceChain,
    uint16 _targetChain
  )
    WormholeL2VoteAggregatorCalldataCompressor(
      _votingToken,
      _relayer,
      _l1BlockAddress,
      _sourceChain,
      _targetChain,
      msg.sender
    )
  {}

  function createProposalVote(uint256 _proposalId, uint128 _against, uint128 _for, uint128 _abstain)
    public
  {
    _proposalVotes[_proposalId] = ProposalVote(_against, _for, _abstain);
  }

  function exposed_castVote(
    uint256 proposalId,
    address voter,
    VoteType support,
    string memory reason
  ) public returns (uint256) {
    return _castVote(proposalId, voter, uint8(support), reason);
  }

  function exposed_domainSeparatorV4() public view returns (bytes32) {
    return _domainSeparatorV4();
  }

  /// @inheritdoc L2GovernorMetadata
  function _addProposal(uint256 proposalId, uint256 voteStart, uint256 voteEnd, bool isCanceled)
    internal
    virtual
    override(L2GovernorMetadata, WormholeL2VoteAggregatorCalldataCompressor)
  {
    WormholeL2VoteAggregatorCalldataCompressor._addProposal(
      proposalId, voteStart, voteEnd, isCanceled
    );
  }
}

contract WormholeL2ERC20CalldataCompressorTest is Test, TestConstants {
  WormholeL2VoteAggregatorCalldataCompressor router;
  FakeERC20 l2Erc20;
  address voterAddress;
  uint256 privateKey;
  WormholeL2VoteAggregatorCalldataCompressorHarness routerHarness;

  event VoteCast(
    address indexed voter, uint256 proposalId, uint8 support, uint256 weight, string reason
  );

  function setUp() public {
    (voterAddress, privateKey) = makeAddrAndKey("voter");
    L1Block l1Block = new L1Block();
    l2Erc20 = new FakeERC20("GovExample", "GOV");
    router = new WormholeL2VoteAggregatorCalldataCompressor(
      address(l2Erc20),
      L2_CHAIN.wormholeRelayer,
      address(l1Block),
      L2_CHAIN.wormholeChainId,
      L1_CHAIN.wormholeChainId,
      msg.sender
    );
    routerHarness = new WormholeL2VoteAggregatorCalldataCompressorHarness(
      address(l2Erc20),
      L2_CHAIN.wormholeRelayer,
      address(l1Block),
      L2_CHAIN.wormholeChainId,
      L1_CHAIN.wormholeChainId
    );
  }

  function _signVoteMessage(uint256 _proposalId, uint8 _support)
    internal
    view
    returns (uint8, bytes32, bytes32)
  {
    bytes32 _voteMessage = keccak256(
      abi.encode(keccak256("Ballot(uint256 proposalId,uint8 support)"), _proposalId, _support)
    );

    bytes32 _voteMessageHash = keccak256(
      abi.encodePacked("\x19\x01", routerHarness.exposed_domainSeparatorV4(), _voteMessage)
    );

    return vm.sign(privateKey, _voteMessageHash);
  }
}

/// @dev All of the internal methods are tested in this Fallback contract
contract Fallback is WormholeL2ERC20CalldataCompressorTest {
  function testFuzz_RevertIf_CastVoteMsgDataIsTooLong(
    uint16 _proposalId,
    uint32 _timeToEnd,
    uint96 _amount
  ) public {
    _timeToEnd = uint32(bound(_timeToEnd, 2000, type(uint32).max));

    vm.assume(_amount != 0);
    vm.assume(_proposalId != 1);
    l2Erc20.mint(address(this), _amount);

    GovernorMetadataMock.Proposal memory l2Proposal =
      routerHarness.createProposal(_proposalId, _timeToEnd);

    vm.roll(l2Proposal.voteStart + 1);
    vm.expectRevert(abi.encode(WormholeL2VoteAggregatorCalldataCompressor.InvalidCalldata.selector));
    (bool ok,) = address(router).call(
      abi.encodePacked(uint8(1), uint256(_proposalId), L2VoteAggregator.VoteType.For)
    );
    assertFalse(ok, "Call did not revert as expected");
  }

  function testFuzz_RevertIf_CastVoteMsgDataIsTooShort(
    uint16 _proposalId,
    uint32 _timeToEnd,
    uint96 _amount
  ) public {
    _timeToEnd = uint32(bound(_timeToEnd, 2000, type(uint32).max));

    vm.assume(_amount != 0);
    vm.assume(_proposalId != 1);
    l2Erc20.mint(address(this), _amount);

    GovernorMetadataMock.Proposal memory l2Proposal =
      routerHarness.createProposal(_proposalId, _timeToEnd);

    vm.roll(l2Proposal.voteStart + 1);
    vm.expectRevert(abi.encode(WormholeL2VoteAggregatorCalldataCompressor.InvalidCalldata.selector));
    (bool ok,) = address(router).call(
      abi.encodePacked(uint8(1), uint8(_proposalId), L2VoteAggregator.VoteType.For)
    );
    assertFalse(ok, "Call did not revert as expected");
  }

  function testFuzz_CorrectlyCastVoteFor(uint16 _proposalId, uint32 _timeToEnd, uint96 _amount)
    public
  {
    _timeToEnd = uint32(bound(_timeToEnd, 2000, type(uint32).max));

    vm.assume(_amount != 0);
    vm.assume(_proposalId != 1);
    l2Erc20.mint(address(this), _amount);

    GovernorMetadataMock.Proposal memory l2Proposal =
      routerHarness.createProposal(_proposalId, _timeToEnd);

    vm.roll(l2Proposal.voteStart + 1);
    vm.expectEmit();
    emit VoteCast(address(this), _proposalId, 1, _amount, "");

    (bool ok,) = address(routerHarness).call(
      abi.encodePacked(uint8(1), uint16(_proposalId), L2VoteAggregator.VoteType.For)
    );
    assertTrue(ok);
    (, uint256 forVotes,) = routerHarness.proposalVotes(_proposalId);

    assertEq(forVotes, _amount, "Votes for is not correct");
  }

  function testFuzz_CorrectlyCastVoteAgainst(uint16 _proposalId, uint32 _timeToEnd, uint96 _amount)
    public
  {
    _timeToEnd = uint32(bound(_timeToEnd, 2000, type(uint32).max));

    vm.assume(_amount != 0);
    vm.assume(_proposalId != 1);
    l2Erc20.mint(address(this), _amount);

    GovernorMetadataMock.Proposal memory l2Proposal =
      routerHarness.createProposal(_proposalId, _timeToEnd);

    vm.roll(l2Proposal.voteStart + 1);
    vm.expectEmit();
    emit VoteCast(address(this), _proposalId, 0, _amount, "");

    (bool ok,) = address(routerHarness).call(
      abi.encodePacked(uint8(1), uint16(_proposalId), L2VoteAggregator.VoteType.Against)
    );
    assertTrue(ok);
    (uint256 againstVotes,,) = routerHarness.proposalVotes(_proposalId);

    assertEq(againstVotes, _amount, "Votes Against is not correct");
  }

  function testFuzz_CorrectlyCastVoteAbstain(uint16 _proposalId, uint32 _timeToEnd, uint96 _amount)
    public
  {
    _timeToEnd = uint32(bound(_timeToEnd, 2000, type(uint32).max));

    vm.assume(_amount != 0);
    vm.assume(_proposalId != 1);
    l2Erc20.mint(address(this), _amount);

    GovernorMetadataMock.Proposal memory l2Proposal =
      routerHarness.createProposal(_proposalId, _timeToEnd);

    vm.roll(l2Proposal.voteStart + 1);
    vm.expectEmit();
    emit VoteCast(address(this), _proposalId, 2, _amount, "");

    (bool ok,) = address(routerHarness).call(
      abi.encodePacked(uint8(1), uint16(_proposalId), L2VoteAggregator.VoteType.Abstain)
    );
    assertTrue(ok);
    (,, uint256 abstainVotes) = routerHarness.proposalVotes(_proposalId);

    assertEq(abstainVotes, _amount, "Votes abstained are not correct");
  }

  function testFuzz_CorrectlyCastVoteWithReasonAgainst(
    uint16 _proposalId,
    uint32 _timeToEnd,
    uint96 _amount,
    string memory _reason
  ) public {
    _timeToEnd = uint32(bound(_timeToEnd, 2000, type(uint32).max));
    vm.assume(_amount != 0);
    vm.assume(_proposalId != 1);

    l2Erc20.mint(address(this), _amount);

    GovernorMetadataMock.Proposal memory l2Proposal =
      routerHarness.createProposal(_proposalId, _timeToEnd);

    vm.roll(l2Proposal.voteStart + 1);
    vm.expectEmit();
    emit VoteCast(address(this), _proposalId, 0, _amount, _reason);

    (bool ok,) = address(routerHarness).call(
      abi.encodePacked(uint8(2), uint16(_proposalId), L2VoteAggregator.VoteType.Against, _reason)
    );
    assertTrue(ok);
    (uint256 against,,) = routerHarness.proposalVotes(_proposalId);
    assertEq(against, _amount, "Votes against is not correct");
  }

  function testFuzz_CorrectlyCastVoteWithReasonAbstain(
    uint16 _proposalId,
    uint32 _timeToEnd,
    uint96 _amount,
    string memory _reason
  ) public {
    _timeToEnd = uint32(bound(_timeToEnd, 2000, type(uint32).max));
    vm.assume(_amount != 0);
    vm.assume(_proposalId != 1);

    l2Erc20.mint(address(this), _amount);

    GovernorMetadataMock.Proposal memory l2Proposal =
      routerHarness.createProposal(_proposalId, _timeToEnd);

    vm.roll(l2Proposal.voteStart + 1);
    vm.expectEmit();
    emit VoteCast(address(this), _proposalId, 2, _amount, _reason);

    (bool ok,) = address(routerHarness).call(
      abi.encodePacked(uint8(2), uint16(_proposalId), L2VoteAggregator.VoteType.Abstain, _reason)
    );
    assertTrue(ok);
    (,, uint256 abstain) = routerHarness.proposalVotes(_proposalId);
    assertEq(abstain, _amount, "Votes abstain is not correct");
  }

  function testFuzz_CorrectlyCastVoteWithReasonFor(
    uint16 _proposalId,
    uint32 _timeToEnd,
    uint96 _amount,
    string memory _reason
  ) public {
    _timeToEnd = uint32(bound(_timeToEnd, 2000, type(uint32).max));
    vm.assume(_amount != 0);
    vm.assume(_proposalId != 1);

    l2Erc20.mint(address(this), _amount);

    GovernorMetadataMock.Proposal memory l2Proposal =
      routerHarness.createProposal(_proposalId, _timeToEnd);

    vm.roll(l2Proposal.voteStart + 1);
    vm.expectEmit();
    emit VoteCast(address(this), _proposalId, 1, _amount, _reason);

    (bool ok,) = address(routerHarness).call(
      abi.encodePacked(uint8(2), uint16(_proposalId), L2VoteAggregator.VoteType.For, _reason)
    );
    assertTrue(ok);
    (, uint256 _for,) = routerHarness.proposalVotes(_proposalId);
    assertEq(_for, _amount, "Votes for is not correct");
  }

  function testFuzz_CorrectlyCastVoteBySigFor(uint16 _proposalId, uint32 _timeToEnd, uint96 _amount)
    public
  {
    _timeToEnd = uint32(bound(_timeToEnd, 2000, type(uint32).max));
    vm.assume(_amount != 0);
    vm.assume(_proposalId != 1);

    L2VoteAggregator.VoteType _voteType = L2VoteAggregator.VoteType.For;

    vm.prank(voterAddress);
    l2Erc20.mint(voterAddress, _amount);

    GovernorMetadataMock.Proposal memory l2Proposal =
      routerHarness.createProposal(_proposalId, _timeToEnd);

    vm.roll(l2Proposal.voteStart + 1);
    vm.expectEmit();
    emit VoteCast(voterAddress, _proposalId, 1, _amount, "");

    (uint8 _v, bytes32 _r, bytes32 _s) = _signVoteMessage(_proposalId, uint8(_voteType));

    (bool ok,) = address(routerHarness).call(
      abi.encodePacked(uint8(3), uint16(_proposalId), _voteType, _v, _r, _s)
    );
    assertTrue(ok);
    (, uint256 _for,) = routerHarness.proposalVotes(_proposalId);
    assertEq(_for, _amount, "Votes for is not correct");
  }

  function testFuzz_CorrectlyCastVoteBySigAbstain(
    uint16 _proposalId,
    uint32 _timeToEnd,
    uint96 _amount
  ) public {
    _timeToEnd = uint32(bound(_timeToEnd, 2000, type(uint32).max));
    vm.assume(_amount != 0);
    vm.assume(_proposalId != 1);

    L2VoteAggregator.VoteType _voteType = L2VoteAggregator.VoteType.Abstain;

    vm.prank(voterAddress);
    l2Erc20.mint(voterAddress, _amount);

    GovernorMetadataMock.Proposal memory l2Proposal =
      routerHarness.createProposal(_proposalId, _timeToEnd);

    vm.roll(l2Proposal.voteStart + 1);
    vm.expectEmit();
    emit VoteCast(voterAddress, _proposalId, uint8(_voteType), _amount, "");

    (uint8 _v, bytes32 _r, bytes32 _s) = _signVoteMessage(_proposalId, uint8(_voteType));

    (bool ok,) = address(routerHarness).call(
      abi.encodePacked(uint8(3), uint16(_proposalId), _voteType, _v, _r, _s)
    );
    assertTrue(ok);
    (,, uint256 _abstain) = routerHarness.proposalVotes(_proposalId);
    assertEq(_abstain, _amount, "Votes abstain is not correct");
  }

  function testFuzz_CorrectlyCastVoteBySigAgainst(
    uint16 _proposalId,
    uint32 _timeToEnd,
    uint96 _amount
  ) public {
    _timeToEnd = uint32(bound(_timeToEnd, 2000, type(uint32).max));
    vm.assume(_amount != 0);
    vm.assume(_proposalId != 1);

    L2VoteAggregator.VoteType _voteType = L2VoteAggregator.VoteType.Against;

    vm.prank(voterAddress);
    l2Erc20.mint(voterAddress, _amount);

    GovernorMetadataMock.Proposal memory l2Proposal =
      routerHarness.createProposal(_proposalId, _timeToEnd);

    vm.roll(l2Proposal.voteStart + 1);
    vm.expectEmit();
    emit VoteCast(voterAddress, _proposalId, uint8(_voteType), _amount, "");

    (uint8 _v, bytes32 _r, bytes32 _s) = _signVoteMessage(_proposalId, uint8(_voteType));

    (bool ok,) = address(routerHarness).call(
      abi.encodePacked(uint8(3), uint16(_proposalId), _voteType, _v, _r, _s)
    );
    assertTrue(ok);
    (uint256 _against,,) = routerHarness.proposalVotes(_proposalId);
    assertEq(_against, _amount, "Votes against is not correct");
  }

  function testFuzz_RevertIf_CastVoteWithReasonMsgDataIsTooShort(
    uint16 _proposalId,
    uint32 _timeToEnd,
    uint96 _amount,
    string calldata _reason
  ) public {
    _timeToEnd = uint32(bound(_timeToEnd, 2000, type(uint32).max));
    vm.assume(_amount != 0);
    vm.assume(_proposalId != 1);

    L2VoteAggregator.VoteType _voteType = L2VoteAggregator.VoteType.Abstain;

    vm.prank(voterAddress);
    l2Erc20.mint(voterAddress, _amount);

    GovernorMetadataMock.Proposal memory l2Proposal =
      routerHarness.createProposal(_proposalId, _timeToEnd);

    vm.roll(l2Proposal.voteStart + 1);

    vm.expectRevert(abi.encode(WormholeL2VoteAggregatorCalldataCompressor.InvalidCalldata.selector));
    (bool ok,) = address(routerHarness).call(
      abi.encodePacked(uint8(2), uint8(_proposalId), _voteType, _reason)
    );
    assertFalse(ok, "Call did not revert as expected");
  }

  function testFuzz_RevertIf_CastVoteBySigMsgDataIsTooShort(
    uint16 _proposalId,
    uint32 _timeToEnd,
    uint96 _amount
  ) public {
    _timeToEnd = uint32(bound(_timeToEnd, 2000, type(uint32).max));
    vm.assume(_amount != 0);
    vm.assume(_proposalId != 1);

    L2VoteAggregator.VoteType _voteType = L2VoteAggregator.VoteType.Abstain;

    vm.prank(voterAddress);
    l2Erc20.mint(voterAddress, _amount);

    GovernorMetadataMock.Proposal memory l2Proposal =
      routerHarness.createProposal(_proposalId, _timeToEnd);

    vm.roll(l2Proposal.voteStart + 1);

    (uint8 _v, bytes32 _r, bytes32 _s) = _signVoteMessage(_proposalId, uint8(_voteType));

    vm.expectRevert(abi.encode(WormholeL2VoteAggregatorCalldataCompressor.InvalidCalldata.selector));
    (bool ok,) = address(routerHarness).call(
      abi.encodePacked(uint8(3), uint8(_proposalId), _voteType, _v, _r, _s)
    );
    assertFalse(ok, "Call did not revert as expected");
  }

  function testFuzz_RevertIf_CastVoteBySigMsgDataIsTooLong(
    uint16 _proposalId,
    uint32 _timeToEnd,
    uint96 _amount
  ) public {
    _timeToEnd = uint32(bound(_timeToEnd, 2000, type(uint32).max));
    vm.assume(_amount != 0);
    vm.assume(_proposalId != 1);

    L2VoteAggregator.VoteType _voteType = L2VoteAggregator.VoteType.Abstain;

    vm.prank(voterAddress);
    l2Erc20.mint(voterAddress, _amount);

    GovernorMetadataMock.Proposal memory l2Proposal =
      routerHarness.createProposal(_proposalId, _timeToEnd);

    vm.roll(l2Proposal.voteStart + 1);
    (uint8 _v, bytes32 _r, bytes32 _s) = _signVoteMessage(_proposalId, uint8(_voteType));

    vm.expectRevert(abi.encode(WormholeL2VoteAggregatorCalldataCompressor.InvalidCalldata.selector));
    (bool ok,) = address(routerHarness).call(
      abi.encodePacked(uint8(3), uint24(_proposalId), _voteType, _v, _r, _s)
    );
    assertFalse(ok, "Call did not revert as expected");
  }

  function testFuzz_RevertIf_FunctionIdDoesNotExist(uint8 _funcId) public {
    _funcId = uint8(bound(_funcId, 4, type(uint8).max));
    vm.expectRevert(
      abi.encode(WormholeL2VoteAggregatorCalldataCompressor.FunctionDoesNotExist.selector)
    );
    (bool ok,) = address(routerHarness).call(abi.encodePacked(_funcId));
    assertFalse(ok);
  }
}
