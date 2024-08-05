// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script, console2 } from 'forge-std/Script.sol';

import { ERC1967Proxy } from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import { SkateVertexVault } from '../src/SkateVertexVault.sol';
import { ISpotEngine } from '../src/interfaces/vertex/ISpotEngine.sol';
import { IPerpEngine } from '../src/interfaces/vertex/IPerpEngine.sol';
import { IEndpoint } from '../src/interfaces/vertex/IEndpoint.sol';
import { ERC20 } from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract mint is Script {
    function run() external {
        uint256 pk = vm.envUint('PK');
        vm.startBroadcast(pk);

        ERC20 usdc = ERC20(0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9);
        SkateVertexVault vault = SkateVertexVault(0x34d63Ef1189d925F47876DCbf7496D0598c6156d);
        usdc.approve(address(vault), 1e6);
        vault.mint(1e6, 1e18);
        vm.stopBroadcast();
    }
}
