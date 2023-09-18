// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {WormholeL1ERC20Bridge} from "src/WormholeL1ERC20Bridge.sol";

contract L1ERC20BridgeHarness is WormholeL1ERC20Bridge {
  constructor(
    address _l1Token,
    address _l1Relayer,
    address _l1Governor,
    uint16 _sourceId,
    uint16 _targetId
  ) WormholeL1ERC20Bridge(_l1Token, _l1Relayer, _l1Governor, _sourceId, _targetId) {}

  function exposed_withdraw(address account, uint256 amount) public {
    _withdraw(account, amount);
  }

  function exposed_receiveWithdrawalWormholeMessages(
    bytes memory payload,
    bytes[] memory additionalVaas,
    bytes32 callerAddr,
    uint16 sourceChain,
    bytes32 deliveryHash
  ) public {
    _receiveWithdrawalWormholeMessages(
      payload, additionalVaas, callerAddr, sourceChain, deliveryHash
    );
  }
}
