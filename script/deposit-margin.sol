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
        ERC20 usdc = ERC20(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);
        uint256 pk = vm.envUint('PK');
        vm.startBroadcast(pk);

        SkateVertexVault vault = SkateVertexVault(0x849Dd9D48337D1884C3bE140ba27CBe63B81d7be);
        usdc.transfer(address(vault), 1e6);

        address[] memory targets = new address[](2);
        bytes[] memory datas = new bytes[](2);

        targets[0] = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
        targets[1] = 0xbbEE07B3e8121227AfCFe1E2B82772246226128e;

        uint256 amount = 1 * 10 ** 6;
        datas[0] =
            abi.encodeWithSignature('approve(address,uint256)', 0xbbEE07B3e8121227AfCFe1E2B82772246226128e, amount);
        datas[1] = abi.encodeWithSignature('depositCollateral(bytes12,uint32,uint128)', bytes12(0x0), 0, amount);

        vault.multicallByManager(targets, datas);
        vm.stopBroadcast();
    }
}
