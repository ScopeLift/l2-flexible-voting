// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {ERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {ERC20Votes} from "openzeppelin/token/ERC20/extensions/ERC20Votes.sol";
import {ERC20Permit} from "openzeppelin/token/ERC20/extensions/ERC20Permit.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";
import {IWormhole} from "wormhole/interfaces/IWormhole.sol";
import {WormholeReceiver} from "src/WormholeReceiver.sol";

contract L2ERC20 is ERC20Votes, WormholeReceiver {
  /// @param _name The name of the ERC20 token.
  /// @param _symbol The symbol of the ERC20 token.
  /// @param _core The address of the Wormhole core contracts.
  constructor(string memory _name, string memory _symbol, address _core)
    WormholeReceiver(_core)
    ERC20(_name, _symbol)
    ERC20Permit(_name)
  {}

  /// @param encodedMsg An encoded message payload sent from a specialized relayer.
  function receiveEncodedMsg(bytes memory encodedMsg) public override {
    (IWormhole.VM memory vm,,) = _validateMessage(encodedMsg);

    (address account, uint256 amount) = abi.decode(vm.payload, (address, uint256));
    _mint(account, amount);
  }
}
