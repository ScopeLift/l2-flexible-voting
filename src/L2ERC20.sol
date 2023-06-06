// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Inherit the ERC20Votes
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

contract L2ERC20 is ERC20Votes {
  // TODO this can only be called by the wormhole relayer.
  // function mint(address account, uint256 amount) external public {
  //   	  _mint(account, amount);
  // }

  // Decode message and then call _mint
    function receiveWormholeMessages(
      bytes memory payload,
      bytes[] memory additionalVaas,
      bytes32 sourceAddress,
      uint16 sourceChain,
      bytes32 deliveryHash
  ) public payable override {}

  modifier onlyRelayerContract() {
    require(msg.sender == WORMHOLE_RELAYER_ADDRESS, "msg.sender is not WormholeRelayer contract.");
    _;
  }
}
