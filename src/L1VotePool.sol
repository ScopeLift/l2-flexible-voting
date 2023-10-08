// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IGovernor} from "openzeppelin/governance/Governor.sol";
import {ERC20Votes} from "openzeppelin/token/ERC20/extensions/ERC20Votes.sol";

import {IFractionalGovernor} from
  "flexible-voting/src/interfaces/IFractionalGovernor.sol";



abstract contract L1VotePool {
  /// @notice The address of the L1 Governor contract.
  IGovernor public immutable GOVERNOR;

  // This param is ignored by the governor when voting with fractional
  // weights. It makes no difference what vote type this is.
  uint8 constant UNUSED_SUPPORT_PARAM = uint8(1);

  event VoteCast(
    address indexed voter,
    uint256 proposalId,
    uint256 voteAgainst,
    uint256 voteFor,
    uint256 voteAbstain
  );

  /// @dev Thrown when proposal does not exist.
  error MissingProposal();

  /// @dev Thrown when a proposal vote is invalid.
  error InvalidProposalVote();

  /// @dev Contains the distribution of a proposal vote.
  struct ProposalVote {
    uint128 againstVotes;
    uint128 forVotes;
    uint128 abstainVotes;
  }

  /// @notice A mapping of proposal id to the proposal vote distribution.
  mapping(uint256 => ProposalVote) public proposalVotes;

  /// @param _governor The address of the L1 Governor contract.
  constructor(address _governor) {
    GOVERNOR = IGovernor(_governor);
	ERC20Votes(IFractionalGovernor(address(GOVERNOR)).token()).delegate(address(this));
  }

  /// @notice Casts vote to the L1 Governor.
  /// @param proposalId The id of the proposal being cast.
  function _castVote(uint256 proposalId, ProposalVote memory vote) internal {
    bytes memory votes = abi.encodePacked(vote.againstVotes, vote.forVotes, vote.abstainVotes);

    // TODO: string should probably mention chain
    GOVERNOR.castVoteWithReasonAndParams(
      proposalId, UNUSED_SUPPORT_PARAM, "rolled-up vote from governance L2 token holders", votes
    );

    emit VoteCast(msg.sender, proposalId, vote.againstVotes, vote.forVotes, vote.abstainVotes);
  }
}
