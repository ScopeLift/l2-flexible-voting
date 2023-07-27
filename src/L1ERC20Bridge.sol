// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20Votes} from "openzeppelin/token/ERC20/extensions/ERC20Votes.sol";
import {IWormhole} from "wormhole/interfaces/IWormhole.sol";

import {console2} from "forge-std/console2.sol";
import {L1VotePool} from "src/L1VotePool.sol";
import {WormholeSender} from "src/WormholeSender.sol";

contract L1ERC20Bridge is L1VotePool, WormholeSender {
  /// @notice L1 token used for deposits and voting.
  ERC20Votes public immutable L1_TOKEN;

  /// @notice Token address which is minted on L2.
  address public L2_TOKEN_ADDRESS;

  /// @notice A unique number used to send messages.
  uint32 public nonce;

  /// @notice Used to indicate whether the contract has been initialized with the L2 token address.
  bool public INITIALIZED = false;

  /// @dev Contract is already initialized with an L2 token.
  error AlreadyInitialized();

  /// @param l1TokenAddress The address of the L1 token.
  /// @param _relayer The adddress of the Wormhole relayer.
  /// @param _governor The address of the L1 governor.
  /// @param _targetChain The Wormhole id of the chain to send the message.
  constructor(address l1TokenAddress, address _relayer, address _governor, uint16 _targetChain)
    L1VotePool(_relayer, _governor)
    WormholeSender(_relayer, _targetChain)
  {
    L1_TOKEN = ERC20Votes(l1TokenAddress);
  }

  /// @notice Must be called before bridging tokens to L2.
  /// @param l2TokenAddress The address of the L2 token.
  function initialize(address l2TokenAddress) public {
    if (INITIALIZED) revert AlreadyInitialized();
    INITIALIZED = true;
    L2_TOKEN_ADDRESS = l2TokenAddress;
  }

  /// @notice Deposits L1 tokens into bridge and publishes a message using Wormhole to the L2 token.
  /// @param account The address of the user on L2 where to mint the token.
  /// @param amount The amount of tokens to deposit and mint on the L2.
  function deposit(address account, uint256 amount) external payable {
    L1_TOKEN.transferFrom(msg.sender, address(this), amount);

    // TODO optimize with encodePacked
    bytes memory mintCalldata = abi.encode(account, amount);

    uint256 cost = quoteDeliveryCost(TARGET_CHAIN);
    require(cost == msg.value, "Cost should be msg.Value");

    WORMHOLE_RELAYER.sendPayloadToEvm{value: cost}(
      TARGET_CHAIN,
      L2_TOKEN_ADDRESS,
      mintCalldata,
      0, // no receiver value needed since we're just passing a message
      GAS_LIMIT
    );
  }

  // TODO test with when refactored with L1Vote
  function receiveWormholeMessages(
    bytes memory payload,
    bytes[] memory additionalVaas,
    bytes32 callerAddr,
    uint16 sourceChain,
    bytes32 deliveryHash
  ) public override onlyRelayer {
    console2.logBytes32(bytes32(uint256(uint160(L2_TOKEN_ADDRESS))));
    console2.logBytes32(callerAddr);
    if (callerAddr == bytes32(uint256(uint160(L2_TOKEN_ADDRESS)))) {
      return _receiveWithdrawalWormholeMessages(
        payload, additionalVaas, callerAddr, sourceChain, deliveryHash
      );
    }
    return _receiveCastVoteWormholeMessages(
      payload, additionalVaas, callerAddr, sourceChain, deliveryHash
    );
  }

  /// @notice Receives an encoded withdrawal message from the L2
  /// @param payload The payload that was sent to in the delivery request.
  function _receiveWithdrawalWormholeMessages(
    bytes memory payload,
    bytes[] memory,
    bytes32,
    uint16,
    bytes32
  ) internal {
    (address account, uint256 amount) = abi.decode(payload, (address, uint256));
    _withdraw(account, amount);
  }

  /// @notice Withdraws deposited tokens to an account.
  /// @param account The address of the user withdrawing tokens.
  /// @param amount The amount of tokens to withdraw.
  function _withdraw(address account, uint256 amount) internal {
    L1_TOKEN.transfer(account, amount);
  }
}
