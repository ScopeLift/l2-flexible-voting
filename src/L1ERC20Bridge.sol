// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {IWormhole} from "wormhole/interfaces/IWormhole.sol";

contract L1ERC20Bridge {
  IERC20 public immutable L1_TOKEN;
  address public L2_TOKEN_ADDRESS;

  IWormhole coreBridge;

  uint32 public nonce;

  bool public INITIALIZED = false;
  mapping(address => uint256) public depositAmount;

  constructor(address l1TokenAddress, address _core) {
    L1_TOKEN = IERC20(l1TokenAddress);
    coreBridge = IWormhole(_core);
    nonce = 0;
  }

  function initialize(address l2TokenAddress) public {
    if (!INITIALIZED) {
      INITIALIZED = true;
      L2_TOKEN_ADDRESS = l2TokenAddress;
    }
  }

  function deposit(address account, uint256 amount) external payable returns (uint64 sequence) {
    L1_TOKEN.transferFrom(msg.sender, address(this), amount);
    depositAmount[account] += amount;

    // TODO optimize with encodePacked
    bytes memory mintCalldata = abi.encode(account, amount);
    sequence = coreBridge.publishMessage(nonce, mintCalldata, 1);
    nonce = nonce + 1;
    return sequence;
  }
}
