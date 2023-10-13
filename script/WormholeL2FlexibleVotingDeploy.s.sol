// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {WormholeL1GovernorMetadataBridge} from "src/WormholeL1GovernorMetadataBridge.sol";
import {WormholeL2GovernorMetadata} from "src/WormholeL2GovernorMetadata.sol";

import {GovernorCountingFractional} from "flexible-voting/src/GovernorCountingFractional.sol";
import {Script, stdJson} from "forge-std/Script.sol";
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
import {CompTimelock} from "openzeppelin/mocks/compound/CompTimelock.sol";

import {L1Block} from "src/L1Block.sol";
import {FakeERC20} from "src/FakeERC20.sol";
import {WormholeL1ERC20Bridge} from "src/WormholeL1ERC20Bridge.sol";
import {WormholeL2ERC20} from "src/WormholeL2ERC20.sol";
import {WormholeL2VoteAggregator} from "src/WormholeL2VoteAggregator.sol";
import {ScriptConstants} from "test/Constants.sol";
import {GovernorFlexibleVotingMock} from "test/mock/GovernorMock.sol";
import {ERC20VotesCompMock} from "test/mock/ERC20VotesCompMock.sol";
import {console2} from "forge-std/console2.sol";

contract GovernorTestnetSettings {
  function quorum(uint256) public view virtual returns (uint256) {
    return 1_000_000;
  }

  function votingDelay() public view virtual returns (uint256) {
    return 90;
  }

  function votingPeriod() public view virtual returns (uint256) {
    return 1800;
  }

  function proposalThreshold() public view virtual returns (uint256) {
    return 500_000;
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

/// @notice Deploy all the necessary components for L2 Flexible Voting.
contract WormholeL2FlexibleVotingDeploy is Script, ScriptConstants {
  using stdJson for string;

  event Configuration(
    address governorAddress,
    address l1TokenAddress,
    address l1BlockAddress,
    address contractOwner,
    string l2TokenName,
    string l2TokenSymbol,
    bool compToken
  );

  function run() public {
    setFallbackToDefaultRpcUrls(false);

    address l1BlockAddress = vm.envOr("L1_BLOCK_ADDRESS", address(0));
    string memory l2TokenName = vm.envOr("L2_TOKEN_NAME", string("Scopeapotomus"));
    string memory l2TokenSymbol = vm.envOr("L2_TOKEN_SYMBOL", string("SCOPE"));

    uint256 l1ForkId = vm.createSelectFork(L1_CHAIN.rpcUrl);
    (address governorAddress, address l1TokenAddress, bool compToken) = _setupGovernor();

    emit Configuration(
      governorAddress,
      l1TokenAddress,
      l1BlockAddress,
      vm.envOr("CONTRACT_OWNER", msg.sender),
      l2TokenName,
      l2TokenSymbol,
      compToken
    );

    // Create L1 bridge that mints the L2 token
    vm.broadcast();
    // For some reason the token method is not working
    WormholeL1ERC20Bridge l1TokenBridge =
    new WormholeL1ERC20Bridge(l1TokenAddress, L1_CHAIN.wormholeRelayer, governorAddress, L1_CHAIN.wormholeChainId, L2_CHAIN.wormholeChainId, vm.envOr("CONTRACT_OWNER", msg.sender));

    // Create L1 metadata bridge that sends proposal metadata to L2
    vm.broadcast();
    WormholeL1GovernorMetadataBridge l1MetadataBridge =
    new WormholeL1GovernorMetadataBridge(governorAddress, L1_CHAIN.wormholeRelayer, L1_CHAIN.wormholeChainId, L2_CHAIN.wormholeChainId);

    vm.createSelectFork(L2_CHAIN.rpcUrl);
    emit Configuration(
      governorAddress,
      l1TokenAddress,
      l1BlockAddress,
      vm.envOr("CONTRACT_OWNER", msg.sender),
      l2TokenName,
      l2TokenSymbol,
      compToken
    );

    if (l1BlockAddress == address(0)) {
      vm.broadcast();
      L1Block l1Block = new L1Block();
      l1BlockAddress = address(l1Block);
    }

    // Deploy the L2 metadata contract
    vm.broadcast();
    WormholeL2GovernorMetadata l2GovernorMetadata =
    new WormholeL2GovernorMetadata(L2_CHAIN.wormholeRelayer, vm.envOr("CONTRACT_OWNER", msg.sender));

    // Create L2 ERC20Votes token
    vm.broadcast();
    WormholeL2ERC20 l2Token =
    new WormholeL2ERC20(l2TokenName, l2TokenSymbol, L2_CHAIN.wormholeRelayer, l1BlockAddress, L2_CHAIN.wormholeChainId, L1_CHAIN.wormholeChainId, vm.envOr("CONTRACT_OWNER", msg.sender));

    // Deploy the L2 vote aggregator
    vm.broadcast();
    WormholeL2VoteAggregator voteAggregator =
    new WormholeL2VoteAggregator(address(l2Token), L2_CHAIN.wormholeRelayer, address(l2GovernorMetadata), l1BlockAddress, L2_CHAIN.wormholeChainId, L1_CHAIN.wormholeChainId);

    vm.broadcast();
    l2GovernorMetadata.setRegisteredSender(
      L1_CHAIN.wormholeChainId, _toWormholeAddress(address(l1MetadataBridge))
    );

    // Register L1 ERC20 bridge on L2 token
    vm.broadcast();
    l2Token.setRegisteredSender(
      L2_CHAIN.wormholeChainId, _toWormholeAddress(address(l1TokenBridge))
    );

    vm.broadcast();
    voteAggregator.initialize(address(l1TokenBridge));

    vm.broadcast();
    l2Token.initialize(address(l1TokenBridge));

    vm.selectFork(l1ForkId);

    // Register L2 token on ERC20 bridge
    vm.broadcast();
    l1TokenBridge.setRegisteredSender(
      L2_CHAIN.wormholeChainId, _toWormholeAddress(address(l2Token))
    );

    // Register Vote Aggregator on L1ERC20 bridge
    vm.broadcast();
    l1TokenBridge.setRegisteredSender(
      L2_CHAIN.wormholeChainId, _toWormholeAddress(address(voteAggregator))
    );

    vm.broadcast();
    l1MetadataBridge.initialize(address(l2GovernorMetadata));

    vm.broadcast();
    l1TokenBridge.initialize(address(l2Token));
  }

  function _setupGovernor() internal returns (address, address, bool) {
    address governorAddress = vm.envOr("L1_GOVERNOR_ADDRESS", address(0));
    address l1TokenAddress = vm.envOr("L1_TOKEN_ADDRESS", address(0));
    bool compToken = vm.envOr("L1_COMP_TOKEN", false);

    // Deploy L1 token on is not provided
    if (l1TokenAddress == address(0)) {
      // Create Timelock
      // setPendingAdmin()
      // 	__acceptAdmin()
      if (compToken) {
        vm.broadcast();
        ERC20VotesCompMock deployedL1Token = new ERC20VotesCompMock("GovernanceComp", "GOVc");
        l1TokenAddress = address(deployedL1Token);
      } else {
        vm.broadcast();
        FakeERC20 deployedL1Token = new FakeERC20("Governance", "GOV");
        l1TokenAddress = address(deployedL1Token);
      }
    }
    // Deploy the L1 governor used in the L1 bridge
    if (governorAddress == address(0)) {
      vm.broadcast();
      TimelockController _timelock =
        new TimelockController(300 , new address[](0), new address[](0), address(0));

      if (compToken) {
        vm.broadcast();
        GovernorCompTestnet gov =
        new GovernorCompTestnet("Dao of Tests", ERC20VotesComp(l1TokenAddress), ICompoundTimelock(payable(_timelock)));
        ERC20Votes(gov.token()).delegate(address(this));
        governorAddress = address(gov);
      } else {
        vm.broadcast();
        GovernorTestnet gov =
          new GovernorTestnet("Dao of Tests", ERC20Votes(l1TokenAddress), _timelock);
        governorAddress = address(gov);
      }
    }
    return (governorAddress, l1TokenAddress, compToken);
  }
}
