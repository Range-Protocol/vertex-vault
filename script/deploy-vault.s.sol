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
        uint256 pk = vm.envUint('PK');
        vm.startBroadcast(pk);

        //        address implementation = address(new SkateBlitzVault());
        //        console2.log('Implementation: ', implementation);

        SkateBlitzVault vault = SkateBlitzVault(
            address(
                new ERC1967Proxy(
                    0xC100EBB15ff173E7d9b457b10BC4192AeA205dAb,
                    abi.encodeWithSignature(
                        'initialize(address,address,address,address,address,string,string,address)',
                        address(spotEngine),
                        address(perpEngine),
                        address(endpoint),
                        usdb,
                        manager,
                        'Skate Blitz Liquidity Vault (Alts)',
                        'SK-LP',
                        upgrader
                    )
                )
            )
        );

        console2.log('Vault: ', address(vault));
        vm.stopBroadcast();
    }
}
