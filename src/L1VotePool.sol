// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IGovernor} from "openzeppelin/governance/Governor.sol";

abstract contract L1VotePool {
  /// @notice The address of the L1 Governor contract.
  IGovernor public governor;

  /// @dev Thrown when proposal does not exist.
  error MissingProposal();

  /// @dev Thrown when a proposal vote is invalid.
  error InvalidProposalVote();

  /// @dev Contains the distribution of a proposal vote.
  struct ProposalVote {
    uint128 inFavor;
    uint128 against;
    uint128 abstain;
  }

  /// @notice A mapping of proposal id to the proposal vote distribution.
  mapping(uint256 => ProposalVote) public proposalVotes;

  /// @param _governor The address of the L1 Governor contract.
  constructor(address _governor) {
    governor = IGovernor(_governor);
  }

  /// @notice Casts vote to the L1 Governor.
  /// @param proposalId The id of the proposal being cast.
  function _castVote(uint256 proposalId, ProposalVote memory vote) internal {
    bytes memory votes = abi.encodePacked(vote.against, vote.inFavor, vote.abstain);

    // This param is ignored by the governor when voting with fractional
    // weights. It makes no difference what vote type this is.
    uint8 unusedSupportParam = uint8(1);

    // TODO: string should probably mention chain
    governor.castVoteWithReasonAndParams(
      proposalId, unusedSupportParam, "rolled-up vote from governance L2 token holders", votes
    );
  }
}
