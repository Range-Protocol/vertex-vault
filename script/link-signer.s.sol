// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script, console2 } from 'forge-std/Script.sol';

import { ERC1967Proxy } from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import { SkateBlitzVault } from '../src/SkateBlitzVault.sol';
import { ISpotEngine } from '../src/interfaces/vertex/ISpotEngine.sol';
import { IPerpEngine } from '../src/interfaces/vertex/IPerpEngine.sol';
import { IEndpoint } from '../src/interfaces/vertex/IEndpoint.sol';
import { ERC20 } from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

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

    ISpotEngine spotEngine = ISpotEngine(0x57c1AB256403532d02D1150C5790423967B22Bf2);
    IPerpEngine perpEngine = IPerpEngine(0x0bc0c84976e21aaF7bE71d318eD93A5f5c9978A4);
    IEndpoint endpoint = IEndpoint(0x00F076FE36f2341A1054B16ae05FcE0C65180DeD);
    ERC20 usdb = ERC20(0x4300000000000000000000000000000000000003);
    address externalAccount = 0x3f132Af5eA90C71ed5DE495962426b8f1B47A511;
    address contractAccount = 0x4C6da96359884b8d485DA1cE49153aC86F1Ddd30;

    SkateBlitzVault vault = SkateBlitzVault(contractAccount);

    function run() external {
        uint256 pk = vm.envUint('PK');
        vm.startBroadcast(pk);

        usdb.transfer(address(vault), 1e6);
        address[] memory targets = new address[](2);
        bytes[] memory data = new bytes[](2);

        targets[0] = address(usdb);
        data[0] = abi.encodeCall(ERC20.approve, (address(endpoint), 1e6));

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

        vault.multicallByManager(targets, data);
        vm.stopBroadcast();
    }
}
