// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// L1 transfer
// https://github.com/wormhole-foundation/wormhole/blob/main/ethereum/contracts/bridge/Bridge.sol#L191
//
// L2 Process
// https://github.com/wormhole-foundation/wormhole/blob/main/ethereum/contracts/bridge/Bridge.sol#L431
//
// Whether we trust the untrusted relayer https://book.wormhole.com/technical/evm/relayer.html

// Test from optimism Goerli to optimism goerli

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
// TODO import wormhole relayer
import {IWormholeRelayer} from "wormhole/interfaces/relayer/IWormholeRelayer.sol"

contract L1ERC20Bridge {
  IERC20 public immutable L1_TOKEN;
  address public immutable L2_TOKEN_ADDRESS;

  // trusted relayer contract on this chain
  IWormholeRelayer immutable relayer;

  // Wormhole id for the target chain
  uint16 public immutable targetChain;

  // Contract address on the target chain. We can probably use
  // create2 for this.
  address public immutable targetContract;

  constructor(
    address l1TokenAddress,
    address l2TokenAddress,
    address _coreRelayer,
    uint16 targetChain,
    address targetContract
  ) {
    L1_TOKEN = IERC20(l1TokenAddress);
    L2_TOKEN_ADDRESS = l2TokenAddress;
    relayer = IWormholeRelayer(_coreRelayer);
    targetChain = targetChain;
    targetContract = targetContract;
  }

  function deposit(address account, uint256 amount, address refundAccount, uint16 refundChain)
    external payable returns (uint64 sequence)
  {
    // TODO keep track of deposit
    L1_TOKEN.transferFrom(msg.sender, address(this), amount);
    // mint on L2
    // 1. encode packed mint args
    // 2. send message to relayer contract
    // 3. On L2 token receive and mint
    return _l2Mint(account, amount, refundAccount, refundChain);
  }

  // Can't really test because relayers not released yet
  function _l2Mint(address account, uint256 amount, address refundAccount, uint16 refundChain) external payable returns (uint64 sequence) {
    bytes memory mintCalldata = abi.encode(account, amount);

    // TODO: Random value invoked on the target chain
    uint256 gasLimit = 500_000;

    //calculate cost to deliver message
    (uint256 deliveryCost,) = relayer.quoteEVMDeliveryPrice(targetChain, receiverValue, gasLimit);

    // Receiver value is 0 because we aren't passing any value
    // to the target contract.
    return relayer.sendPayloadToEvm{value: deliveryCost}(
      targetChain, targetContract, mintCalldata, 0, gasLimit, refundChain, refundAccount
    );
  }
}
