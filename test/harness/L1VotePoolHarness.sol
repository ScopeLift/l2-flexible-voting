// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {FakeERC20} from "src/FakeERC20.sol";
import {WormholeBase} from "src/WormholeBase.sol";
import {WormholeL1VotePool} from "src/WormholeL1VotePool.sol";
import {WormholeReceiver} from "src/WormholeReceiver.sol";

contract L1VotePoolHarness is WormholeL1VotePool, WormholeReceiver, Test {
  constructor(address _relayer, address _l1Governor)
    WormholeBase(_relayer)
    WormholeL1VotePool(_l1Governor)
    WormholeReceiver(msg.sender)
  {}

  function receiveWormholeMessages(
    bytes calldata payload,
    bytes[] memory additionalVaas,
    bytes32 sourceAddress,
    uint16 sourceChain,
    bytes32 deliveryHash
  )
    public
    override
    onlyRelayer
    isRegisteredSender(sourceChain, sourceAddress)
    replayProtect(deliveryHash)
  {
    (uint256 proposalId,,,) = abi.decode(payload, (uint256, uint128, uint128, uint128));
    _jumpToActiveProposal(proposalId);
    _receiveCastVoteWormholeMessages(
      payload, additionalVaas, sourceAddress, sourceChain, deliveryHash
    );
  }

  function _createExampleProposal(address l1Erc20) internal returns (uint256) {
    bytes memory proposalCalldata = abi.encode(FakeERC20.mint.selector, address(GOVERNOR), 100_000);

    address[] memory targets = new address[](1);
    bytes[] memory calldatas = new bytes[](1);
    uint256[] memory values = new uint256[](1);

    targets[0] = address(l1Erc20);
    calldatas[0] = proposalCalldata;
    values[0] = 0;

    return GOVERNOR.propose(targets, values, calldatas, "Proposal: To inflate token");
  }

  function createProposalVote(address l1Erc20) public returns (uint256) {
    uint256 _proposalId = _createExampleProposal(l1Erc20);
    return _proposalId;
  }

  function createProposalVote(address l1Erc20, uint128 _against, uint128 _for, uint128 _abstain)
    public
    returns (uint256)
  {
    uint256 _proposalId = _createExampleProposal(l1Erc20);
    _jumpToActiveProposal(_proposalId);
    _receiveCastVoteWormholeMessages(
      abi.encode(_proposalId, _against, _for, _abstain),
      new bytes[](0),
      bytes32(""),
      uint16(0),
      bytes32("")
    );
    return _proposalId;
  }

  function _jumpToActiveProposal(uint256 proposalId) internal {
    uint256 _deadline = GOVERNOR.proposalDeadline(proposalId);
    vm.roll(_deadline - 1);
  }
}
