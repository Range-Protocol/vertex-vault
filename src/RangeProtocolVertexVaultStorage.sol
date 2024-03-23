// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import { IERC20 } from '@openzeppelin/contracts/interfaces/IERC20.sol';
import { AggregatorV3Interface } from '@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol';
import { IRangeProtocolVertexVault } from './interfaces/IRangeProtocolVertexVault.sol';
import { IEndpoint } from './interfaces/vertex/IEndpoint.sol';
import { IPerpEngine } from './interfaces/vertex/IPerpEngine.sol';
import { ISpotEngine } from './interfaces/vertex/ISpotEngine.sol';

abstract contract RangeProtocolVertexVaultStorage is IRangeProtocolVertexVault {
    bytes32 public contractSubAccount;
    IERC20 public usdc;
    uint256[] public productIds;
    mapping(uint256 productId => bool whitelisted) public isWhiteListedProduct;
    IEndpoint public endpoint;
    IPerpEngine public perpEngine;
    ISpotEngine public spotEngine;
    uint256 public managingFee;
    uint256 public managerBalance;
    IERC20 public wETH;
    IERC20 public wBTC;
    mapping(IERC20 => AggregatorV3Interface) public tokenToPriceOracle;
    address public upgrader;
    uint256 public swapThreshold;
    uint256 public minimumSwapInterval;
    uint256 public lastSwapTimestamp;
    mapping(address => bool) public whitelistedTargets;
    address[] public targets;
    mapping(address => bool) public whitelistedSwapRouters;
    address[] public swapRouters;
    // Note: do not change the layout of the above state variable and only add new state variable below.
}
