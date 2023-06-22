// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {IWormhole} from "wormhole/interfaces/IWormhole.sol";

contract L1ERC20Bridge {
  /// @notice L1 token used for deposits and voting.
  IERC20 public immutable L1_TOKEN;

  /// @notice Token address which is minted on L2.
  address public L2_TOKEN_ADDRESS;

  /// @notice The core Wormhole contract used to send messages to L2.
  IWormhole coreBridge;

  /// @notice A unique number used to send messages.
  uint32 public nonce;

  /// @notice Used to indicate whether the contract has been intialized with the L2 token address.
  bool public INITIALIZED = false;

  /// @notice A mapping of users to amount they have deposited into the bridge.
  mapping(address => uint256) public depositAmount;

  /// @param l1TokenAddress The address of the L1 token.
  /// @param _core The address of the core wormhole contract.
  constructor(address l1TokenAddress, address _core) {
    L1_TOKEN = IERC20(l1TokenAddress);
    coreBridge = IWormhole(_core);
    nonce = 0;
  }

  /// @notice Must be called before bridging tokens to L2.
  /// @param l2TokenAddress The address of the L2 token.
  function initialize(address l2TokenAddress) public {
    if (!INITIALIZED) {
      INITIALIZED = true;
      L2_TOKEN_ADDRESS = l2TokenAddress;
    }
  }

  /// @notice Deposits L1 tokens into bridge and publishes a message using Wormhole to the L2 token.
  /// @param account The address of the user on L2 where to mint the token.
  /// @param amount The amount of tokens to deposit and mint on the L2.
  function deposit(address account, uint256 amount) external payable returns (uint64 sequence) {
    L1_TOKEN.transferFrom(msg.sender, address(this), amount);
    L1_TOKEN.delegate(account);
    depositAmount[account] += amount;

    // TODO optimize with encodePacked
    bytes memory mintCalldata = abi.encode(account, amount);
    sequence = coreBridge.publishMessage(nonce, mintCalldata, 1);
    nonce = nonce + 1;
    return sequence;
  }
}
