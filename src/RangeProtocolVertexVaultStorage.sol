// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { IERC20 } from '@openzeppelin/contracts/interfaces/IERC20.sol';
import { IRangeProtocolVertexVault } from
    './interfaces/IRangeProtocolVertexVault.sol';
import { IEndPoint } from './interfaces/vertex/IEndPoint.sol';
import { IPerpEngine } from './interfaces/vertex/IPerpEngine.sol';
import { ISpotEngine } from './interfaces/vertex/ISpotEngine.sol';

abstract contract RangeProtocolVertexVaultStorage is
    IRangeProtocolVertexVault
{
    bytes32 public contractSubAccount;
    IERC20 public depositToken;
    uint256[] public productIds;
    mapping(uint256 productId => bool whitelisted) public isWhiteListedProduct;
    IEndPoint public endPoint;
    IPerpEngine public perpEngine;
    ISpotEngine public spotEngine;
    uint256 public managingFee;
    uint256 public managerBalance;
}
