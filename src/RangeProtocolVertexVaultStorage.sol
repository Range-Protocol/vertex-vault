// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import { IERC20 } from '@openzeppelin/contracts/interfaces/IERC20.sol';
import { IRangeProtocolVertexVault } from './interfaces/IRangeProtocolVertexVault.sol';
import { IEndpoint } from './interfaces/vertex/IEndpoint.sol';
import { IPerpEngine } from './interfaces/vertex/IPerpEngine.sol';
import { ISpotEngine } from './interfaces/vertex/ISpotEngine.sol';

abstract contract RangeProtocolVertexVaultStorage is IRangeProtocolVertexVault {
    bytes32 public contractSubAccount;
    IERC20 public usdb;
    uint256[] public productIds;
    mapping(uint256 productId => bool whitelisted) public isWhiteListedProduct;
    IEndpoint public endpoint;
    IPerpEngine public perpEngine;
    ISpotEngine public spotEngine;
    uint256 public managingFee;
    uint256 public managerBalance;
    address public upgrader;
    mapping(address => bool) public whitelistedTargets;
    address[] public targets;
}
