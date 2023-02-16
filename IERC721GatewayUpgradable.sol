//SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.17;

interface IERC721GatewayUpgradableEmitter {
  /// event for backend tracking
  event SwapIn(uint256 tokenId, address receiver);
  /// event for gas limit update
  event GasLimitUpdate(uint256 newGasLimit);
  /// event for gas price update
  event GasPriceUpdate(uint256 newGasPrice);
  /// @dev pay for swapOut gas is not enough
  error InvalidGasPayment();
  /// @dev limit nft transfer to specific function
  error InvalidTransfer();
}

interface IERC721GatewayUpgradable is IERC721GatewayUpgradableEmitter {
  function reLocate(uint256 tokenId, address receiver) external payable;

  function reLocateBatch(uint256[] calldata tokenId, address receiver) external payable;

  function setOutGasLimit(uint256 gasLimit) external;

  function setOutGasPrice(uint256 gasPrice) external;

  function calculateGasTokenAmount() external view returns (uint256);

  function getToken() external view returns (address);
}