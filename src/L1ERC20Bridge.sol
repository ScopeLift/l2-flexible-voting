// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
// TODO import wormhole relayer
import {IWormhole} from "wormhole/interfaces/IWormhole.sol";
import {console2} from "forge-std/console2.sol";

contract L1ERC20Bridge {
  IERC20 public immutable L1_TOKEN;
  address public L2_TOKEN_ADDRESS;

  IWormhole immutable coreBridge;

  uint32 public nonce;

  bool public INITIALIZED = false;

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

  function deposit(address account, uint256 amount, address refundAccount, uint16 refundChain)
    external
    payable
    returns (uint64 sequence)
  {
    // TODO keep track of deposit
    L1_TOKEN.transferFrom(msg.sender, address(this), amount);
    return _l2Mint(account, amount, refundAccount, refundChain);
  }

  function _l2Mint(address account, uint256 amount, address refundAccount, uint16 refundChain)
    internal
    returns (uint64 sequence)
  {
		  // TODO optimize with encodePacked
    bytes memory mintCalldata = abi.encode(account, amount);
    sequence = coreBridge.publishMessage(nonce, mintCalldata, 1);
    nonce = nonce + 1;
    return sequence;
  }
}
