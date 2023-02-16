//SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.17;

import { IERC721ReceiverUpgradeable } from '@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol';
import { UUPSUpgradeable } from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import { ReentrancyGuardUpgradeable } from '@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol';
import { PausableUpgradeable } from '@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol';
import { AggregatorV3Interface } from '@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol';

import { SafeOwnableUpgradeable } from '@p12/contracts-lib/contracts/access/SafeOwnableUpgradeable.sol';

import { IP12Badge } from './interface/IP12Badge.sol';
import { IERC721GatewayUpgradable } from './interface/IERC721GatewayUpgradable.sol';

contract ERC721GatewayUpgradable is
  IERC721GatewayUpgradable,
  SafeOwnableUpgradeable,
  UUPSUpgradeable,
  IERC721ReceiverUpgradeable,
  ReentrancyGuardUpgradeable,
  PausableUpgradeable
{
  address public constant NULL_ADDRESS = 0x0000000000000000000000000000000000000001;

  AggregatorV3Interface private _maticAggregator;
  AggregatorV3Interface private _bnbAggregator;

  uint256 public outGasPrice;
  uint256 public outGasLimit;
  /// @dev P12 Badge address
  IP12Badge private _token;

  function initialize(
    AggregatorV3Interface maticAggregator,
    AggregatorV3Interface bnbAggregator,
    IP12Badge token,
    address owner_
  ) public initializer {
    _maticAggregator = maticAggregator;
    _bnbAggregator = bnbAggregator;
    _token = token;

    __ReentrancyGuard_init_unchained();
    __Pausable_init_unchained();
    __Ownable_init_unchained(owner_);
  }

  // solhint-disable-next-line no-empty-blocks
  function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

  /**
   * @dev entry function for NFT cross-chain
   * @dev hero IO's skill
   */
  function reLocate(uint256 tokenId, address receiver) public payable override {
    _payGas();
    _swapIn(tokenId, receiver);
    emit SwapIn(tokenId, receiver);
  }

  /**
   * @dev entry function for NFT cross-chain in batch
   * @dev hero IO's skill
   */
  function reLocateBatch(uint256[] calldata tokenIds, address receiver) public payable override {
    _payGas(tokenIds.length);
    for (uint256 i = 0; i < tokenIds.length; i++) {
      _swapIn(tokenIds[i], receiver);
      emit SwapIn(tokenIds[i], receiver);
    }
  }

  /**
   * @dev get token to be crossed address
   */
  function getToken() external view override returns (address) {
    return address(_token);
  }

  /**
   * @dev Received ERC-721 function
   * @dev check data to disallow directly transfer by mistake
   * @dev use swapIn instead
   */
  function onERC721Received(
    address,
    address,
    uint256,
    bytes calldata
  ) external pure override returns (bytes4) {
    if (msg.sig != this.reLocate.selector) {
      revert InvalidTransfer();
    }
    return this.onERC721Received.selector;
  }

  /**
   * @dev calculate how much matic is required
   */
  function calculateGasTokenAmount() public view returns (uint256) {
    // solhint-disable-next-line no-unused-vars
    (uint80 _a, int256 maticAnswer, uint256 _b, uint256 _c, uint80 _d) = _maticAggregator.latestRoundData();
    // solhint-disable-next-line no-unused-vars
    (uint80 _e, int256 bnbAnswer, uint256 _f, uint256 _g, uint80 _h) = _bnbAggregator.latestRoundData();
    uint256 convertedInGas = (outGasPrice * outGasLimit * uint256(bnbAnswer)) / uint256(maticAnswer);
    return convertedInGas;
  }

  /**
   * @dev pay gas in native token of mint token on another chain
   * @dev specifically, in token is Matic, out token is BNB
   */
  function _payGas() internal {
    uint256 convertedInGas = calculateGasTokenAmount();
    if (msg.value < convertedInGas) {
      revert InvalidGasPayment();
    }
    // refund gas fee
    payable(msg.sender).transfer(msg.value - convertedInGas);
  }

  /**
   * @dev pay gas for certain amount token transfer
   * @dev pay gas in native token of mint token on another chain
   * @dev specifically, in token is Matic, out token is BNB
   */
  function _payGas(uint256 amount) internal {
    uint256 convertedInGas = calculateGasTokenAmount();
    if (msg.value < convertedInGas * amount) {
      revert InvalidGasPayment();
    }

    // refund gas fee
    payable(msg.sender).transfer(msg.value - convertedInGas * amount);
  }

  /// @dev set swap out gas limit
  function setOutGasLimit(uint256 gasLimit) public override onlyOwner {
    outGasLimit = gasLimit;
    emit GasLimitUpdate(outGasLimit);
  }

  /// @dev set swap out gas price
  function setOutGasPrice(uint256 gasPrice) public onlyOwner {
    outGasPrice = gasPrice;
    emit GasPriceUpdate(outGasPrice);
  }

  /**
   * @dev user call this method to burn/lock p12 badge
   * @dev then emit an event for backend to mint a new one on another chain
   */
  function _swapIn(uint256 tokenId, address receiver) internal {
    _token.transferFrom(msg.sender, address(NULL_ADDRESS), tokenId);

    emit SwapIn(tokenId, receiver);
  }
}