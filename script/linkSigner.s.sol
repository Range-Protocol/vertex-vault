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

contract linkSigner is Script {
    struct LinkSignerStruct {
        bytes32 sender;
        bytes32 signer;
        uint64 nonce;
    }

    struct SlowModeTx {
        uint64 executableAt;
        address sender;
        bytes tx;
    }

    ISpotEngine spotEngine =
        ISpotEngine(0x32d91Af2B17054D575A7bF1ACfa7615f41CCEfaB);
    IPerpEngine perpEngine =
        IPerpEngine(0xb74C78cca0FADAFBeE52B2f48A67eE8c834b5fd1);
    IEndpoint endpoint = IEndpoint(0xbbEE07B3e8121227AfCFe1E2B82772246226128e);
    IUSDC usdc = IUSDC(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);
    address manager = 0x2B986A355F5676F77687A84b3209Af8654b2C6aa;
    address externalAccount = 0x2B986A355F5676F77687A84b3209Af8654b2C6aa;
    address contractAccount = 0xCb60Ca32B25b4E11cD1959514d77356D58d3E138;

    RangeProtocolVertexVault vault =
        RangeProtocolVertexVault(0xCb60Ca32B25b4E11cD1959514d77356D58d3E138);

    function run() external {
        uint256 pk = vm.envUint('PK');
        vm.startBroadcast(pk);

        usdc.transfer(address(vault), 1e6);

        address[] memory targets = new address[](2);
        bytes[] memory data = new bytes[](2);
        uint256[] memory values = new uint256[](2);

        targets[0] = address(usdc);
        data[0] = abi.encodeCall(IUSDC.approve, (address(endpoint), 1e6));
        values[0] = 0;

        targets[1] = address(endpoint);
        data[1] = abi.encodeCall(
            IEndpoint.submitSlowModeTransaction,
            abi.encodePacked(
                uint8(19),
                abi.encode(
                    LinkSignerStruct(
                        bytes32(uint256(uint160(contractAccount)) << 96),
                        bytes32(uint256(uint160(externalAccount)) << 96),
                        0
                    )
                )
            )
        );
        values[1] = 0;

        //        vault.multicallByManager(targets, data, values);
        vm.stopBroadcast();
    }
}
