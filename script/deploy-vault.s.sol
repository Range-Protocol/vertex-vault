// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script, console2 } from 'forge-std/Script.sol';

import { ERC1967Proxy } from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import { SkateVertexVault } from '../src/SkateVertexVault.sol';
import { ISpotEngine } from '../src/interfaces/vertex/ISpotEngine.sol';
import { IPerpEngine } from '../src/interfaces/vertex/IPerpEngine.sol';
import { IEndpoint } from '../src/interfaces/vertex/IEndpoint.sol';

contract deployVault is Script {
    ISpotEngine spotEngine = ISpotEngine(0xb64d2d606DC23D7a055B770e192631f5c8e1d9f8);
    IPerpEngine perpEngine = IPerpEngine(0x38080ee5fb939d045A9e533dF355e85Ff4f7e13D);
    IEndpoint endpoint = IEndpoint(0x526D7C7ea3677efF28CB5bA457f9d341F297Fd52);
    address USDC = 0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9;
    address manager = 0x3f132Af5eA90C71ed5DE495962426b8f1B47A511;
    address upgrader = 0xBBE307DB73D8fD981A7dAB929E2a41225CF0658A;

    function run() external {
        uint256 pk = vm.envUint('PK');
        vm.startBroadcast(pk);

        address implementation = address(new SkateVertexVault());
        console2.log('Implementation: ', implementation);

        SkateVertexVault vault = SkateVertexVault(
            address(
                new ERC1967Proxy(
                    implementation,
                    abi.encodeWithSignature(
                        'initialize(address,address,address,address,address,string,string,address)',
                        address(spotEngine),
                        address(perpEngine),
                        address(endpoint),
                        USDC,
                        manager,
                        'Skate Blitz Liquidity Vault (Majors)',
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
