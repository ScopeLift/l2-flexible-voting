// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

// Inherit the ERC20Votes
import {ERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {ERC20Votes} from "openzeppelin/token/ERC20/extensions/ERC20Votes.sol";
import {ERC20Permit} from "openzeppelin/token/ERC20/extensions/ERC20Permit.sol";
import {IWormhole} from "wormhole/interfaces/IWormhole.sol";
import {console2} from "forge-std/console2.sol";

contract L2ERC20 is ERC20Votes {
  IWormhole immutable coreBridge;

  mapping(uint16 => bytes32) _applicationContracts;
  mapping(bytes32 => bool) _completedMessages;
  address owner;

  constructor(string memory _name, string memory _symbol, address _core) ERC20(_name, _symbol) ERC20Permit(_name) {
    coreBridge = IWormhole(_core);
    owner = msg.sender;
  }

  function receiveEncodedMsg(bytes memory encodedMsg) public {
    (IWormhole.VM memory vm, bool valid, string memory reason) =
      coreBridge.parseAndVerifyVM(encodedMsg);

    //1. Check Wormhole Guardian Signatures
    //  If the VM is NOT valid, will return the reason it's not valid
    //  If the VM IS valid, reason will be blank
    require(valid, reason);
	console2.logBytes32(vm.emitterAddress);
	console2.logBytes32(_applicationContracts[vm.emitterChainId]);

    //2. Check if the Emitter Chain contract is registered
    require(
      _applicationContracts[vm.emitterChainId] == vm.emitterAddress, "Invalid Emitter Address!"
    );

    //3. Check that the message hasn't already been processed
    require(!_completedMessages[vm.hash], "Message already processed");
    _completedMessages[vm.hash] = true;

    (address account, uint256 amount) = abi.decode(vm.payload, (address, uint256));
    _mint(account, amount);
  }

  function registerApplicationContracts(uint16 chainId, bytes32 applicationAddr) public {
    // require(msg.sender == owner, "Only owner can register new chains!");
    _applicationContracts[chainId] = applicationAddr;
  }
}
