// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script, console2 } from 'forge-std/Script.sol';

import { ERC1967Proxy } from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import { SkateVertexVault } from '../src/SkateVertexVault.sol';
import { ISpotEngine } from '../src/interfaces/vertex/ISpotEngine.sol';
import { IPerpEngine } from '../src/interfaces/vertex/IPerpEngine.sol';
import { IEndpoint } from '../src/interfaces/vertex/IEndpoint.sol';
import { ERC20 } from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract depositMargin is Script {
    function run() external {
        uint256 pk = vm.envUint('PK');
        vm.startBroadcast(pk);

        ERC20 usdc = ERC20(0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9);
        SkateVertexVault vault = SkateVertexVault(0x34d63Ef1189d925F47876DCbf7496D0598c6156d);

        address[] memory targets = new address[](2);
        bytes[] memory datas = new bytes[](2);

        targets[0] = 0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9;
        targets[1] = 0x526D7C7ea3677efF28CB5bA457f9d341F297Fd52;

        uint256 amount = 5 * 10 ** 6;
        datas[0] =
            abi.encodeWithSignature('approve(address,uint256)', 0x526D7C7ea3677efF28CB5bA457f9d341F297Fd52, amount);
        datas[1] = abi.encodeWithSignature('depositCollateral(bytes12,uint32,uint128)', bytes12(0x0), 0, amount);

        vault.multicallByManager(targets, datas);
        vm.stopBroadcast();
    }
}