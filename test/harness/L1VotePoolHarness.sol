// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {CommonBase} from "forge-std/Base.sol";

import {L1VotePool} from "src/L1VotePool.sol";
import {FakeERC20} from "src/FakeERC20.sol";

contract L1VotePoolHarness is L1VotePool, CommonBase {
  constructor(address _governor) L1VotePool(_governor) {}

  function exposed_castVote(uint256 proposalId, ProposalVote memory vote) public {
    _castVote(proposalId, vote);
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

  function _jumpToActiveProposal(uint256 proposalId) public {
    uint256 _deadline = GOVERNOR.proposalDeadline(proposalId);
    vm.roll(_deadline - 1);
  }
}
