// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {Test} from "forge-std/Test.sol";

import {L1Block} from "src/L1Block.sol";
import {L2GovernorMetadata} from "src/L2GovernorMetadata.sol";
import {FakeERC20} from "src/FakeERC20.sol";
import {L2VoteAggregator} from "src/L2VoteAggregator.sol";
import {Constants} from "test/Constants.sol";

contract L2VoteAggregatorTest is Test, Constants {
  function setUp() public {
    vm.createSelectFork(vm.rpcUrl("polygon_mumbai"));
  }
}

contract GovernorMetadataMock is L2GovernorMetadata {
  constructor(address _core) L2GovernorMetadata(_core) {
    _proposals[1] = Proposal({voteStart: block.number, voteEnd: block.number + 3000});
  }

  function getProposal(uint256 proposalId) public view override returns (Proposal memory) {
    return _proposals[1];
  }
}

contract BridgeVote is L2VoteAggregatorTest {
  function testFork_CorrectlyBridgeVote() public {
    vm.roll(block.number);
    FakeERC20 erc20 = new FakeERC20("GovExample", "GOV");
    erc20.mint(address(this), 1 ether);

    GovernorMetadataMock l2GovernorMetadata = new GovernorMetadataMock(wormholeCoreMumbai);
    L1Block l1Block = new L1Block();
    L2VoteAggregator l2VoteAggregator =
    new L2VoteAggregator(address(erc20), wormholeCoreMumbai, address(l2GovernorMetadata), address(l1Block));

    vm.roll(block.number + 5);
    l2VoteAggregator.castVote(1, 1);

    uint64 sequence = l2VoteAggregator.bridgeVote(1);
    assertEq(sequence, 0);
  }
}
