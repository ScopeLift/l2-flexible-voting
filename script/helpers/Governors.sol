// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {
  GovernorVotesComp,
  ERC20VotesComp
} from "openzeppelin-flexible-voting/governance/extensions/GovernorVotesComp.sol";
import {GovernorVotes} from "openzeppelin-flexible-voting/governance/extensions/GovernorVotes.sol";
import {GovernorTimelockControl} from
  "openzeppelin-flexible-voting/governance/extensions/GovernorTimelockControl.sol";
import {ERC20Votes} from "openzeppelin-flexible-voting/token/ERC20/extensions/ERC20Votes.sol";
import {
  Governor as FlexGovernor,
  Governor,
  IGovernor
} from "openzeppelin-flexible-voting/governance/Governor.sol";
import {TimelockController} from "openzeppelin-flexible-voting/governance/TimelockController.sol";
import {GovernorTimelockCompound} from
  "openzeppelin-flexible-voting/governance/extensions/GovernorTimelockCompound.sol";
import {ICompoundTimelock} from "openzeppelin-flexible-voting/vendor/compound/ICompoundTimelock.sol";

import {GovernorCountingFractional} from "flexible-voting/src/GovernorCountingFractional.sol";

contract GovernorTestnetSettings {
  function quorum(uint256) public view virtual returns (uint256) {
    return 1_000_000e18;
  }

  function votingDelay() public view virtual returns (uint256) {
    return 90;
  }

  function votingPeriod() public view virtual returns (uint256) {
    return 1800;
  }

  function proposalThreshold() public view virtual returns (uint256) {
    return 500_000e18;
  }
}

contract GovernorCompTestnet is
  GovernorVotesComp,
  GovernorCountingFractional,
  GovernorTimelockCompound,
  GovernorTestnetSettings
{
  constructor(string memory _name, ERC20VotesComp _token, ICompoundTimelock _timelock)
    FlexGovernor(_name)
    GovernorVotesComp(_token)
    GovernorTimelockCompound(_timelock)
  {}

  function quorum(uint256 blockNumber)
    public
    view
    override(GovernorTestnetSettings, IGovernor)
    returns (uint256)
  {
    return GovernorTestnetSettings.quorum(blockNumber);
  }

  function votingDelay() public view override(GovernorTestnetSettings, IGovernor) returns (uint256) {
    return GovernorTestnetSettings.votingDelay();
  }

  function votingPeriod()
    public
    view
    override(GovernorTestnetSettings, IGovernor)
    returns (uint256)
  {
    return GovernorTestnetSettings.votingPeriod();
  }

  function proposalThreshold()
    public
    view
    override(FlexGovernor, GovernorTestnetSettings)
    returns (uint256)
  {
    return GovernorTestnetSettings.proposalThreshold();
  }

  /// @dev We override this function to resolve ambiguity between inherited contracts.
  function castVoteWithReasonAndParamsBySig(
    uint256 proposalId,
    uint8 support,
    string calldata reason,
    bytes memory params,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) public override(GovernorCountingFractional, IGovernor, FlexGovernor) returns (uint256) {
    return GovernorCountingFractional.castVoteWithReasonAndParamsBySig(
      proposalId, support, reason, params, v, r, s
    );
  }

  /// @dev We override this function to resolve ambiguity between inherited contracts.
  function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(Governor, GovernorTimelockCompound)
    returns (bool)
  {
    return GovernorTimelockCompound.supportsInterface(interfaceId);
  }

  /// @dev We override this function to resolve ambiguity between inherited contracts.
  function state(uint256 proposalId)
    public
    view
    virtual
    override(Governor, GovernorTimelockCompound)
    returns (ProposalState)
  {
    return GovernorTimelockCompound.state(proposalId);
  }

  /// @dev We override this function to resolve ambiguity between inherited contracts.
  function _execute(
    uint256 proposalId,
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
  ) internal virtual override(FlexGovernor, GovernorTimelockCompound) {
    return
      GovernorTimelockCompound._execute(proposalId, targets, values, calldatas, descriptionHash);
  }

  /// @dev We override this function to resolve ambiguity between inherited contracts.
  function _cancel(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
  ) internal virtual override(FlexGovernor, GovernorTimelockCompound) returns (uint256) {
    return GovernorTimelockCompound._cancel(targets, values, calldatas, descriptionHash);
  }

  /// @dev We override this function to resolve ambiguity between inherited contracts.
  function _executor()
    internal
    view
    virtual
    override(FlexGovernor, GovernorTimelockCompound)
    returns (address)
  {
    return GovernorTimelockCompound._executor();
  }
}

contract GovernorTestnet is
  GovernorVotes,
  GovernorCountingFractional,
  GovernorTestnetSettings,
  GovernorTimelockControl
{
  constructor(string memory _name, ERC20Votes _token, TimelockController _timelock)
    FlexGovernor(_name)
    GovernorVotes(_token)
    GovernorTimelockControl(_timelock)
  {}

  function quorum(uint256 blockNumber)
    public
    view
    override(GovernorTestnetSettings, IGovernor)
    returns (uint256)
  {
    return GovernorTestnetSettings.quorum(blockNumber);
  }

  function votingDelay() public view override(GovernorTestnetSettings, IGovernor) returns (uint256) {
    return GovernorTestnetSettings.votingDelay();
  }

  function votingPeriod()
    public
    view
    override(GovernorTestnetSettings, IGovernor)
    returns (uint256)
  {
    return GovernorTestnetSettings.votingPeriod();
  }

  function proposalThreshold()
    public
    view
    override(FlexGovernor, GovernorTestnetSettings)
    returns (uint256)
  {
    return GovernorTestnetSettings.proposalThreshold();
  }

  function castVoteWithReasonAndParamsBySig(
    uint256 proposalId,
    uint8 support,
    string calldata reason,
    bytes memory params,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) public override(GovernorCountingFractional, IGovernor, FlexGovernor) returns (uint256) {
    return GovernorCountingFractional.castVoteWithReasonAndParamsBySig(
      proposalId, support, reason, params, v, r, s
    );
  }

  /// @dev We override this function to resolve ambiguity between inherited contracts.
  function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(Governor, GovernorTimelockControl)
    returns (bool)
  {
    return GovernorTimelockControl.supportsInterface(interfaceId);
  }

  /// @dev We override this function to resolve ambiguity between inherited contracts.
  function state(uint256 proposalId)
    public
    view
    virtual
    override(Governor, GovernorTimelockControl)
    returns (ProposalState)
  {
    return GovernorTimelockControl.state(proposalId);
  }

  /// @dev We override this function to resolve ambiguity between inherited contracts.
  function _execute(
    uint256 proposalId,
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
  ) internal virtual override(FlexGovernor, GovernorTimelockControl) {
    return GovernorTimelockControl._execute(proposalId, targets, values, calldatas, descriptionHash);
  }

  /// @dev We override this function to resolve ambiguity between inherited contracts.
  function _cancel(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
  ) internal virtual override(FlexGovernor, GovernorTimelockControl) returns (uint256) {
    return GovernorTimelockControl._cancel(targets, values, calldatas, descriptionHash);
  }

  /// @dev We override this function to resolve ambiguity between inherited contracts.
  function _executor()
    internal
    view
    virtual
    override(FlexGovernor, GovernorTimelockControl)
    returns (address)
  {
    return GovernorTimelockControl._executor();
  }
}
