// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

// Inherit the ERC20Votes
import {EIP712} from "openzeppelin/utils/cryptography/EIP712.sol";
import {ERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {ERC20Votes} from "openzeppelin/token/ERC20/extensions/ERC20Votes.sol";
import {ERC20Permit} from "openzeppelin/token/ERC20/extensions/ERC20Permit.sol";
import {IWormholeReceiver} from "wormhole/interfaces/relayer/IWormholeReceiver.sol";

contract L2ERC20 is ERC20Votes, IWormholeReceiver {
  // TODO this can only be called by the wormhole relayer.
  // function mint(address account, uint256 amount) external public {
  //   	  _mint(account, amount);
  // }
  constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) ERC20Permit(_name) {}

  // Decode message and then call _mint
  function receiveWormholeMessages(
    bytes memory payload,
    bytes[] memory additionalVaas,
    bytes32 sourceAddress,
    uint16 sourceChain,
    bytes32 deliveryHash
  ) public payable {
    // TODO Check sourceAddress
    // TODO Check sourceChain
    // TODO use encodePacked for optimization
    (address mintReceiver, uint256 amount) = abi.decode(payload, (address, uint256));
    _mint(mintReceiver, amount);
  }

  // modifier onlyRelayerContract() {
  //   require(msg.sender == WORMHOLE_RELAYER_ADDRESS, "msg.sender is not WormholeRelayer
  // contract.");
  //   _;
  // }
}
