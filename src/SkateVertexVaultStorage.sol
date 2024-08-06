// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import { IERC20 } from '@openzeppelin/contracts/interfaces/IERC20.sol';
import { ISkateVertexVault } from './interfaces/ISkateVertexVault.sol';
import { IEndpoint } from './interfaces/vertex/IEndpoint.sol';
import { IPerpEngine } from './interfaces/vertex/IPerpEngine.sol';
import { ISpotEngine } from './interfaces/vertex/ISpotEngine.sol';

abstract contract SkateVertexVaultStorage is ISkateVertexVault {
    bytes32 public contractSubAccount;
    IERC20 public usdc;
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
    mapping(address => bool) public whitelistedSwapRouters;
    address[] public swapRouters;
    uint256 public swapThreshold;
    IERC20[] public assets;
    mapping(IERC20 asset => AssetData) public assetsData;
    mapping(uint256 spotId => IERC20 asset) public spotIdToAsset;

    struct IncentivesData {
        address arb;
        address vrtx;
        bytes32 arbMerkleRoot;
        bytes32 vrtxMerkleRoot;
        mapping(address => uint256) arbClaimedAmounts;
        mapping(address => uint256) vrtxClaimedAmounts;
    }

    IncentivesData public incentivesData;
    // Note: do not change the layout of the above state variable and only add new state variable below.
}
