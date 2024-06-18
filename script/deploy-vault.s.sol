// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script, console2 } from 'forge-std/Script.sol';

import { ERC1967Proxy } from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import { SkateVertexVault } from '../src/SkateVertexVault.sol';
import { ISpotEngine } from '../src/interfaces/vertex/ISpotEngine.sol';
import { IPerpEngine } from '../src/interfaces/vertex/IPerpEngine.sol';
import { IEndpoint } from '../src/interfaces/vertex/IEndpoint.sol';

contract deployVault is Script {
    ISpotEngine spotEngine = ISpotEngine(0x32d91Af2B17054D575A7bF1ACfa7615f41CCEfaB);
    IPerpEngine perpEngine = IPerpEngine(0xb74C78cca0FADAFBeE52B2f48A67eE8c834b5fd1);
    IEndpoint endpoint = IEndpoint(0xbbEE07B3e8121227AfCFe1E2B82772246226128e);
    address USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address manager = 0x3f132Af5eA90C71ed5DE495962426b8f1B47A511;
    address upgrader = 0xBBE307DB73D8fD981A7dAB929E2a41225CF0658A;

    function run() external {
        uint256 pk = vm.envUint('PK');
        vm.startBroadcast(pk);

        //        address implementation = address(new SkateVertexVault());
        //        console2.log('Implementation: ', implementation);

        SkateVertexVault vault = SkateVertexVault(
            address(
                new ERC1967Proxy(
                    0x5b1E52775BA84dee714f46f5a67a5b4f6D452287,
                    abi.encodeWithSignature(
                        'initialize(address,address,address,address,address,string,string,address)',
                        address(spotEngine),
                        address(perpEngine),
                        address(endpoint),
                        USDC,
                        manager,
                        'Skate Vertex Liquidity Vault (Alts)',
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
