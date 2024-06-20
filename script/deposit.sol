// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script, console2 } from 'forge-std/Script.sol';

import { ERC1967Proxy } from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import { SkateBlitzVault } from '../src/SkateBlitzVault.sol';
import { ISpotEngine } from '../src/interfaces/vertex/ISpotEngine.sol';
import { IPerpEngine } from '../src/interfaces/vertex/IPerpEngine.sol';
import { IEndpoint } from '../src/interfaces/vertex/IEndpoint.sol';
import { ERC20 } from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract depositMargin is Script {
    function run() external {
        ERC20 usdb = ERC20(0x4300000000000000000000000000000000000003);
        uint256 pk = vm.envUint('PK');
        vm.startBroadcast(pk);

        SkateBlitzVault vault = SkateBlitzVault(0x4C6da96359884b8d485DA1cE49153aC86F1Ddd30);
        usdb.transfer(address(vault), 5e18);

        address[] memory targets = new address[](2);
        bytes[] memory datas = new bytes[](2);

        targets[0] = address(usdb);
        targets[1] = 0x00F076FE36f2341A1054B16ae05FcE0C65180DeD;

        uint256 amount = 5 * 10 ** 18;
        datas[0] =
            abi.encodeWithSignature('approve(address,uint256)', 0x00F076FE36f2341A1054B16ae05FcE0C65180DeD, amount);
        datas[1] = abi.encodeWithSignature('depositCollateral(bytes12,uint32,uint128)', bytes12(0x0), 0, amount);

        vault.multicallByManager(targets, datas);
        vm.stopBroadcast();
    }
}
