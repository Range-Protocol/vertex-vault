// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script, console2 } from 'forge-std/Script.sol';

import { ERC1967Proxy } from
    '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import { RangeProtocolVertexVault } from '../src/RangeProtocolVertexVault.sol';
import { ISpotEngine } from '../src/interfaces/vertex/ISpotEngine.sol';
import { IPerpEngine } from '../src/interfaces/vertex/IPerpEngine.sol';
import { IEndpoint } from '../src/interfaces/vertex/IEndpoint.sol';

contract upgradeVault is Script {
    function run() external {
        uint256 pk = vm.envUint('PK');
        vm.startBroadcast(pk);

        address implementation = address(new RangeProtocolVertexVault());
        console2.log('implementation address: ', implementation);
        address vault = 0xCb60Ca32B25b4E11cD1959514d77356D58d3E138;
        (bool success,) = vault.call(
            abi.encodeWithSignature(
                'upgradeToAndCall(address,bytes)', implementation, ''
            )
        );
        console2.log('upgrade status:', success);
        vm.stopBroadcast();
    }
}
