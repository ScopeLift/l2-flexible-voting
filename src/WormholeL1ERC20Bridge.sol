// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {ERC20Votes} from "openzeppelin/token/ERC20/extensions/ERC20Votes.sol";
import {WormholeL1VotePool} from "src/WormholeL1VotePool.sol";
import {WormholeSender} from "src/WormholeSender.sol";
import {WormholeBase} from "src/WormholeBase.sol";
import {WormholeReceiver} from "src/WormholeReceiver.sol";

contract WormholeL1ERC20Bridge is WormholeL1VotePool, WormholeSender, WormholeReceiver {
  using SafeERC20 for ERC20Votes;

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
  /// @param _sourceChain The Wormhole id of the chain sending the messages.
  /// @param _targetChain The Wormhole id of the chain to send the message.
  constructor(
    address l1TokenAddress,
    address _relayer,
    address _governor,
    uint16 _sourceChain,
    uint16 _targetChain
  ) WormholeL1VotePool(_governor) WormholeBase(_relayer) WormholeSender(_sourceChain, _targetChain) {
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
  /// @return sequence An identifier for the message published to L2.
  function deposit(address account, uint256 amount) public payable returns (uint256 sequence) {
    L1_TOKEN.safeTransferFrom(msg.sender, address(this), amount);

    // TODO optimize with encodePacked
    bytes memory mintCalldata = abi.encode(account, amount);

    uint256 cost = quoteDeliveryCost(TARGET_CHAIN);
    require(cost == msg.value, "Cost should be msg.Value");

    return WORMHOLE_RELAYER.sendPayloadToEvm{value: cost}(
      TARGET_CHAIN,
      L2_TOKEN_ADDRESS,
      mintCalldata,
      0, // no receiver value needed since we're just passing a message
      GAS_LIMIT,
      SOURCE_CHAIN,
      msg.sender
    );
  }

  function receiveWormholeMessages(
    bytes memory payload,
    bytes[] memory additionalVaas,
    bytes32 sourceAddress,
    uint16 sourceChain,
    bytes32 deliveryHash
  ) public override onlyRelayer isRegisteredSender(sourceChain, sourceAddress) {
    if (sourceAddress == bytes32(uint256(uint160(L2_TOKEN_ADDRESS)))) {
      return _receiveWithdrawalWormholeMessages(
        payload, additionalVaas, sourceAddress, sourceChain, deliveryHash
      );
    }
    return _receiveCastVoteWormholeMessages(
      payload, additionalVaas, sourceAddress, sourceChain, deliveryHash
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
    L1_TOKEN.safeTransfer(account, amount);
  }
}
