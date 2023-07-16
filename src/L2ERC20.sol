// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {ERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {ERC20Votes} from "openzeppelin/token/ERC20/extensions/ERC20Votes.sol";
import {ERC20Permit} from "openzeppelin/token/ERC20/extensions/ERC20Permit.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";
import {SafeCast} from "openzeppelin/utils/math/SafeCast.sol";
import {IWormhole} from "wormhole/interfaces/IWormhole.sol";
import {WormholeReceiver} from "src/WormholeReceiver.sol";
import {IL1Block} from "src/interfaces/IL1Block.sol";

contract L2ERC20 is ERC20Votes, WormholeReceiver {
  /// @notice The contract that handles fetch the L1 block on the L2.
  IL1Block immutable L1_BLOCK;

  /// @param _name The name of the ERC20 token.
  /// @param _symbol The symbol of the ERC20 token.
  /// @param _core The address of the Wormhole core contracts.
  constructor(string memory _name, string memory _symbol, address _core, address _l1Block)
    WormholeReceiver(_core)
    ERC20(_name, _symbol)
    ERC20Permit(_name)
  {
    L1_BLOCK = IL1Block(_l1Block);
  }

  /// @param encodedMsg An encoded message payload sent from a specialized relayer.
  function receiveEncodedMsg(bytes memory encodedMsg) public override {
    (IWormhole.VM memory vm,,) = _validateMessage(encodedMsg);

    (address account, uint256 amount) = abi.decode(vm.payload, (address, uint256));
    _mint(account, amount);
  }

  /// @dev Clock used for flagging checkpoints.
  function clock() public view override returns (uint48) {
    return SafeCast.toUint48(L1_BLOCK.number());
  }

  /// @dev Description of the clock
  function CLOCK_MODE() public view virtual override returns (string memory) {
    // Check that the clock was not modified
    require(clock() == L1_BLOCK.number(), "ERC20Votes: broken clock mode");
    return "mode=blocknumber&from=eip155:1";
  }
}
