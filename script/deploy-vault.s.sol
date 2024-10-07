// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script, console2 } from 'forge-std/Script.sol';

import { ERC1967Proxy } from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import { SkateVertexVault } from '../src/SkateVertexVault.sol';
import { ISpotEngine } from '../src/interfaces/vertex/ISpotEngine.sol';
import { IPerpEngine } from '../src/interfaces/vertex/IPerpEngine.sol';
import { IEndpoint } from '../src/interfaces/vertex/IEndpoint.sol';

contract deployVault is Script {
    ISpotEngine spotEngine = ISpotEngine(0x3E113cde3D6309e9bd45Bf7E273ecBB8b50ca127);
    IPerpEngine perpEngine = IPerpEngine(0x0F54f46979C62aB73D03Da60eBE044c8D63F724f);
    IEndpoint endpoint = IEndpoint(0x2777268EeE0d224F99013Bc4af24ec756007f1a6);
    address USDC = 0x3894085Ef7Ff0f0aeDf52E2A2704928d1Ec074F1;
    address manager = 0xBBE307DB73D8fD981A7dAB929E2a41225CF0658A;
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
