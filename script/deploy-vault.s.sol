// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script, console2 } from 'forge-std/Script.sol';

import { ERC1967Proxy } from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import { SkateVertexVault } from '../src/SkateVertexVault.sol';
import { ISpotEngine } from '../src/interfaces/vertex/ISpotEngine.sol';
import { IPerpEngine } from '../src/interfaces/vertex/IPerpEngine.sol';
import { IEndpoint } from '../src/interfaces/vertex/IEndpoint.sol';

contract deployVault is Script {
    ISpotEngine spotEngine = ISpotEngine(0xe818be1DA4E53763bC77df904aD1B5A1C5A61626);
    IPerpEngine perpEngine = IPerpEngine(0x5BD184F408932F9E6bA00e44A071bCCb8977fb47);
    IEndpoint endpoint = IEndpoint(0x92C2201D48481e2d42772Da02485084A4407Bbe2);
    address USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address manager = 0x38E292E52302351aAdf5Ef51D4d3bb30bD355b25;
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
                        'Skate Vertex Liquidity Vault (Majors)',
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
