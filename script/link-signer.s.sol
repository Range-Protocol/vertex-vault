// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script, console2 } from 'forge-std/Script.sol';

import { ERC1967Proxy } from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import { SkateVertexVault } from '../src/SkateVertexVault.sol';
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

    ISpotEngine spotEngine = ISpotEngine(0xb64d2d606DC23D7a055B770e192631f5c8e1d9f8);
    IPerpEngine perpEngine = IPerpEngine(0x38080ee5fb939d045A9e533dF355e85Ff4f7e13D);
    IEndpoint endpoint = IEndpoint(0x526D7C7ea3677efF28CB5bA457f9d341F297Fd52);
    ERC20 usdc = ERC20(0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9);
    address externalAccount = 0x659806B8b30692E23841A9A0853a16143420feb7;
    address contractAccount = 0x34d63Ef1189d925F47876DCbf7496D0598c6156d;

    SkateVertexVault vault = SkateVertexVault(contractAccount);

    function run() external {
        uint256 pk = vm.envUint('PK');
        vm.startBroadcast(pk);

        usdc.transfer(address(vault), 1e6);
        address[] memory targets = new address[](2);
        bytes[] memory data = new bytes[](2);

        targets[0] = address(usdc);
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
