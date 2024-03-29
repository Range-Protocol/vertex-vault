// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import { IERC20 } from '@openzeppelin/contracts/interfaces/IERC20.sol';

interface IRangeProtocolVertexVault is IERC20 {
    event Minted(address user, uint256 shares, uint256 amount);
    event Burned(address user, uint256 shares, uint256 amount);
    event ProductAdded(uint256 product);
    event ProductRemoved(uint256 product);
    event ManagingFeeSet(uint256 managingFee);
    event TargetAddedToWhitelist(address target);
    event TargetRemovedFromWhitelist(address target);
    event SwapRouterAddedToWhitelist(address swapRouter);
    event SwapRouterRemovedFromWhitelist(address swapRouter);
    event Swapped(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut, uint256 amountOut, uint256 timestamp);
    event SwapThresholdChanged(uint256 swapThreshold);

    function mint(uint256 amount, uint256 minShares) external returns (uint256 shares);
    function burn(uint256 shares, uint256 minAmount) external returns (uint256 amount);
    function swap(address target, bytes calldata swapData, IERC20 tokenIn, uint256 amountIn) external;
    function addProduct(uint256 productId) external;
    function removeProduct(uint256 productId) external;
    function changeUpgrader(address newUpgrader) external;
    function whiteListSwapRouter(address swapRouter) external;
    function removeSwapRouterFromWhitelist(address swapRouter) external;
    function changeSwapThreshold(uint256 newSwapThreshold) external;
    function whiteListTarget(address target) external;
    function removeTargetFromWhitelist(address target) external;
    function multicallByManager(address[] calldata targets, bytes[] calldata data) external;
    function setManagingFee(uint256 _managingFee) external;
    function collectManagerFee() external;
    function getMintAmount(uint256 depositAmount) external view returns (uint256);
    function getUnderlyingBalance() external view returns (uint256);
    function getPendingBalance() external view returns (uint256 pendingBalance);
    function getUnderlyingBalanceByShares(uint256 shares) external view returns (uint256 amount);
}
