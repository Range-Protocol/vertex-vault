// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script, console2 } from 'forge-std/Script.sol';
import { ERC1967Proxy } from
    '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import { RangeProtocolVertexVault } from '../src/RangeProtocolVertexVault.sol';
import { ISpotEngine } from '../src/interfaces/vertex/ISpotEngine.sol';
import { IPerpEngine } from '../src/interfaces/vertex/IPerpEngine.sol';
import { IEndpoint } from '../src/interfaces/vertex/IEndpoint.sol';
import { IUSDC } from './interfaces/IUSDC.sol';

contract burn is Script {
    IUSDC usdc = IUSDC(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);
    RangeProtocolVertexVault vault =
        RangeProtocolVertexVault(0xCb60Ca32B25b4E11cD1959514d77356D58d3E138);

    function run() external {
        uint256 pk = vm.envUint('PK');
        vm.startBroadcast(pk);
        uint256 amount = vault.balanceOf(vault.manager()) / 2;
        vault.burn(amount, 0);
        vault.collectManagerFee();
        vm.stopBroadcast();
    }
}
