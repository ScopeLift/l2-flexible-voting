// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {FakeERC20} from "src/FakeERC20.sol";
import {WormholeL1VotePool} from "src/WormholeL1VotePool.sol";
import {WormholeReceiver} from "src/WormholeReceiver.sol";
import {WormholeBase} from "src/WormholeBase.sol";

contract L1VotePoolHarness is WormholeL1VotePool, WormholeReceiver, Test {
  constructor(address _relayer, address _governor)
    WormholeBase(_relayer)
    WormholeL1VotePool(_governor)
  {}

  // We cannot use the exposed naming
  function exposed_receiveCastWormholeMessages(
    bytes memory payload,
    bytes[] memory additionalVaas,
    bytes32 sourceAddress,
    uint16 sourceChain,
    bytes32 deliveryHash
  ) public {
    (uint256 proposalId,,,) = abi.decode(payload, (uint256, uint128, uint128, uint128));
    _jumpToActiveProposal(proposalId);
    _receiveCastVoteWormholeMessages(
      payload, additionalVaas, sourceAddress, sourceChain, deliveryHash
    );
  }

  function _createExampleProposal(address l1Erc20) internal returns (uint256) {
    bytes memory proposalCalldata = abi.encode(FakeERC20.mint.selector, address(governor), 100_000);

    address[] memory targets = new address[](1);
    bytes[] memory calldatas = new bytes[](1);
    uint256[] memory values = new uint256[](1);

    targets[0] = address(l1Erc20);
    calldatas[0] = proposalCalldata;
    values[0] = 0;

    return governor.propose(targets, values, calldatas, "Proposal: To inflate token");
  }

  function createProposalVote(address l1Erc20) public returns (uint256) {
    uint256 _proposalId = _createExampleProposal(l1Erc20);
    return _proposalId;
  }

  function createProposalVote(address l1Erc20, uint128 _against, uint128 _inFavor, uint128 _abstain)
    public
    returns (uint256)
  {
    uint256 _proposalId = _createExampleProposal(l1Erc20);
    _jumpToActiveProposal(_proposalId);
    _receiveCastVoteWormholeMessages(
      abi.encode(_proposalId, _against, _inFavor, _abstain),
      new bytes[](0),
      bytes32(""),
      uint16(0),
      bytes32("")
    );
    return _proposalId;
  }

  function _jumpToActiveProposal(uint256 proposalId) internal {
    uint256 _deadline = governor.proposalDeadline(proposalId);
    vm.roll(_deadline - 1);
  }

  /// @dev We need this function because when we call `performDelivery` the proposal is not active,
  /// and it does not seem configurable in the wormhole sdk utilities.
  function receiveWormholeMessages(
    bytes memory payload,
    bytes[] memory additionalVaas,
    bytes32 sourceAddress,
    uint16 sourceChain,
    bytes32 deliveryHash
  ) public override onlyRelayer isRegisteredSender(sourceChain, sourceAddress) {
    (uint256 proposalId,,,) = abi.decode(payload, (uint256, uint128, uint128, uint128));
    _jumpToActiveProposal(proposalId);
    _receiveCastVoteWormholeMessages(
      payload, additionalVaas, sourceAddress, sourceChain, deliveryHash
    );
  }

  function receiveWormholeMessages(
    bytes memory payload,
    bytes[] memory additionalVaas,
    bytes32 sourceAddress,
    uint16 sourceChain,
    bytes32 deliveryHash,
    bool jump
  ) public onlyRelayer isRegisteredSender(sourceChain, sourceAddress) {
    (uint256 proposalId,,,) = abi.decode(payload, (uint256, uint128, uint128, uint128));
    if (jump) _jumpToActiveProposal(proposalId);
    _receiveCastVoteWormholeMessages(
      payload, additionalVaas, sourceAddress, sourceChain, deliveryHash
    );
  }

  function _jumpToProposalEnd(uint256 proposalId) external {
    uint256 _deadline = governor.proposalDeadline(proposalId);
    vm.roll(_deadline);
  }

  function _jumpToProposalEnd(uint256 proposalId, uint32 additionalBlocks) external {
    uint256 _deadline = governor.proposalDeadline(proposalId);
    vm.roll(_deadline + additionalBlocks);
  }
}
