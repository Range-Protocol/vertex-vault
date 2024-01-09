// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script, console2 } from 'forge-std/Script.sol';

import { ERC1967Proxy } from
    '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import { RangeProtocolVertexVault } from '../src/RangeProtocolVertexVault.sol';
import { ISpotEngine } from '../src/interfaces/vertex/ISpotEngine.sol';
import { IPerpEngine } from '../src/interfaces/vertex/IPerpEngine.sol';
import { IEndPoint } from '../src/interfaces/vertex/IEndPoint.sol';
import { IUSDC } from './interfaces/IUSDC.sol';

contract AddCollateral is Script {
    IUSDC usdc = IUSDC(0xbC47901f4d2C5fc871ae0037Ea05c3F614690781);

    function run() external {
        uint256 pk = vm.envUint('PK');
        vm.startBroadcast(pk);
        RangeProtocolVertexVault vault =
            RangeProtocolVertexVault(0xcfc719ed73eab9177e307507b971E0cad42544Fa);
        console2.log(vault.manager());
        //        vault.addCollateral(100e6);
        //        vm.stopBroadcast();
    }
}
