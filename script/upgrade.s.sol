// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script, console2 } from 'forge-std/Script.sol';

import { ERC1967Proxy } from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import { SkateBlitzVault } from '../src/SkateBlitzVault.sol';
import { ISpotEngine } from '../src/interfaces/vertex/ISpotEngine.sol';
import { IPerpEngine } from '../src/interfaces/vertex/IPerpEngine.sol';
import { IEndpoint } from '../src/interfaces/vertex/IEndpoint.sol';
import { ERC20 } from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract deployVault is Script {
    ISpotEngine spotEngine = ISpotEngine(0x57c1AB256403532d02D1150C5790423967B22Bf2);
    IPerpEngine perpEngine = IPerpEngine(0x0bc0c84976e21aaF7bE71d318eD93A5f5c9978A4);
    IEndpoint endpoint = IEndpoint(0x00F076FE36f2341A1054B16ae05FcE0C65180DeD);
    ERC20 usdb = ERC20(0x4300000000000000000000000000000000000003);
    address manager = 0x3f132Af5eA90C71ed5DE495962426b8f1B47A511;
    address upgrader = 0xBBE307DB73D8fD981A7dAB929E2a41225CF0658A;

    function run() external {
        vm.startBroadcast();

//        address implementation = address(new SkateBlitzVault());
//        console2.log('Implementation: ', implementation);

        SkateBlitzVault vault = SkateBlitzVault(0x4C6da96359884b8d485DA1cE49153aC86F1Ddd30);
        vault.upgradeToAndCall(0x6efD7F2A5e6A80FFa14E384Ad63D1C93962fCA93, abi.encodeWithSignature("reinit()"));

        console2.log('Vault: ', address(vault));
        vm.stopBroadcast();
    }
}
