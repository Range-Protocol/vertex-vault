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

contract AddCollateral is Script {
    IUSDC usdc = IUSDC(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);

    function run() external {
        uint256 pk = vm.envUint('PK');
        vm.startBroadcast(pk);
        RangeProtocolVertexVault vault =
            RangeProtocolVertexVault(0xCb60Ca32B25b4E11cD1959514d77356D58d3E138);

        address[] memory targets = new address[](2);
        targets[0] = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
        targets[1] = 0xbbEE07B3e8121227AfCFe1E2B82772246226128e;

        bytes[] memory datas = new bytes[](2);

        datas[0] = abi.encodeWithSignature(
            'approve(address,uint256)',
            0xbbEE07B3e8121227AfCFe1E2B82772246226128e,
            26_000_000
        );

        datas[1] = abi.encodeWithSignature(
            'depositCollateralWithReferral(bytes12,uint32,uint128,string)',
            bytes12(0x0),
            0,
            25_000_000,
            'REFERRAL'
        );
        bytes memory data = abi.encodeWithSignature(
            'multicallByManager(address[],bytes[])', targets, datas
        );
        console2.logBytes(data);
        vault.multicallByManager(targets, datas);
        //        address(vault).call(vm.envBytes("data"));
        ////        console2.log(vault.manager());
        ////        //        vault.addCollateral(100e6);
        vm.stopBroadcast();
    }
}
