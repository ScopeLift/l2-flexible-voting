// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {ERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {ERC20Votes} from "openzeppelin/token/ERC20/extensions/ERC20Votes.sol";
import {ERC20Permit} from "openzeppelin/token/ERC20/extensions/ERC20Permit.sol";
import {SafeCast} from "openzeppelin/utils/math/SafeCast.sol";
import {WormholeSender} from "src/WormholeSender.sol";
import {WormholeReceiver} from "src/WormholeReceiver.sol";
import {WormholeBase} from "src/WormholeBase.sol";

import {IL1Block} from "src/interfaces/IL1Block.sol";

contract WormholeL2ERC20 is ERC20Votes, WormholeReceiver, WormholeSender {
  /// @notice The contract that handles fetching the L1 block on the L2.
  IL1Block public immutable L1_BLOCK;

  /// @notice Used to indicate whether the contract has been initialized with the L2 token address.
  bool public INITIALIZED = false;

  /// @notice The L1 token address.
  address public L1_TOKEN_ADDRESS;

  /// @dev Contract is already initialized with an L2 token.
  error AlreadyInitialized();

  /// @param _name The name of the ERC20 token.
  /// @param _symbol The symbol of the ERC20 token.
  /// @param _relayer The address of the Wormhole relayer.
  /// @param _l1Block The contract that manages the clock for the ERC20.
  /// @param _sourceChain The chain sending wormhole messages.
  /// @param _targetChain The chain to send wormhole messages.
  constructor(
    string memory _name,
    string memory _symbol,
    address _relayer,
    address _l1Block,
    uint16 _sourceChain,
    uint16 _targetChain
  )
    WormholeBase(_relayer)
    ERC20(_name, _symbol)
    ERC20Permit(_name)
    WormholeSender(_sourceChain, _targetChain)
  {
    L1_BLOCK = IL1Block(_l1Block);
  }

  /// @notice Must be called before bridging tokens to L2.
  /// @param l1TokenAddress The address of the L1 token for this L2 token.
  function initialize(address l1TokenAddress) public {
    if (INITIALIZED) revert AlreadyInitialized();
    INITIALIZED = true;
    L1_TOKEN_ADDRESS = l1TokenAddress;
  }

  /// @notice Receives a message from L1 and mints L2 tokens.
  /// @param payload The payload that was sent to in the delivery request.
  function receiveWormholeMessages(
    bytes memory payload,
    bytes[] memory,
    bytes32 sourceAddress,
    uint16 sourceChain,
    bytes32
  ) public virtual override onlyRelayer isRegisteredSender(sourceChain, sourceAddress) {
    (address account, uint256 amount) = abi.decode(payload, (address, uint256));
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

  /// @notice Burn L2 tokens and unlock tokens on the L1.
  /// @param account The account where the tokens will be transferred.
  /// @param amount The amount of tokens to be unlocked.
  function l1Unlock(address account, uint256 amount) external payable returns (uint256 sequence) {
    _burn(msg.sender, amount);
    bytes memory withdrawCalldata = abi.encode(account, amount);
    uint256 cost = quoteDeliveryCost(TARGET_CHAIN);
    return WORMHOLE_RELAYER.sendPayloadToEvm{value: cost}(
      TARGET_CHAIN,
      L1_TOKEN_ADDRESS,
      withdrawCalldata,
      0, // no receiver value needed since we're just passing a message
      GAS_LIMIT,
      SOURCE_CHAIN,
      msg.sender
    );
  }
}
