// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script, console2 } from 'forge-std/Script.sol';

import { ERC1967Proxy } from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import { RangeProtocolVertexVault } from '../src/RangeProtocolVertexVault.sol';
import { ISpotEngine } from '../src/interfaces/vertex/ISpotEngine.sol';
import { IPerpEngine } from '../src/interfaces/vertex/IPerpEngine.sol';
import { IEndpoint } from '../src/interfaces/vertex/IEndpoint.sol';

contract deployVault is Script {
    ISpotEngine spotEngine = ISpotEngine(0x32d91Af2B17054D575A7bF1ACfa7615f41CCEfaB);
    IPerpEngine perpEngine = IPerpEngine(0xb74C78cca0FADAFBeE52B2f48A67eE8c834b5fd1);
    IEndpoint endpoint = IEndpoint(0xbbEE07B3e8121227AfCFe1E2B82772246226128e);
    address USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address manager = 0x2B986A355F5676F77687A84b3209Af8654b2C6aa;

    function run() external {
        uint256 pk = vm.envUint('PK');
        vm.startBroadcast(pk);

        //        address implementation = address(new RangeProtocolVertexVault());
        //        console2.log('Implementation: ', implementation);

        RangeProtocolVertexVault vault = RangeProtocolVertexVault(
            address(
                new ERC1967Proxy(
                    0x7019967c27ad36731613eFf0BF16E0f42FF78D78,
                    abi.encodeWithSignature(
                        'initialize(address,address,address,address,address,string,string,address)',
                        address(spotEngine),
                        address(perpEngine),
                        address(endpoint),
                        USDC,
                        manager,
                        'Vertex Alts',
                        'R-VER',
                        manager
                    )
                )
            )
        );

        console2.log('Vault: ', address(vault));
        vm.stopBroadcast();
    }
}
