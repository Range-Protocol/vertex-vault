// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script, console2 } from 'forge-std/Script.sol';

import { ERC1967Proxy } from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import { RangeProtocolVertexVault } from '../src/RangeProtocolVertexVault.sol';
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

    ISpotEngine spotEngine = ISpotEngine(0x32d91Af2B17054D575A7bF1ACfa7615f41CCEfaB);
    IPerpEngine perpEngine = IPerpEngine(0xb74C78cca0FADAFBeE52B2f48A67eE8c834b5fd1);
    IEndpoint endpoint = IEndpoint(0xbbEE07B3e8121227AfCFe1E2B82772246226128e);
    ERC20 usdc = ERC20(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);
    address externalAccount = 0x5b1c179F201B629E9b8F20cF66f617D151D53886;
    address contractAccount = 0xAeC565391155C80AdEb9e26E426621aA78aA0744;

    RangeProtocolVertexVault vault = RangeProtocolVertexVault(0xAeC565391155C80AdEb9e26E426621aA78aA0744);

    function run() external {
        uint256 pk = vm.envUint('PK');
        vm.startBroadcast(pk);

//        usdc.transfer(address(vault), 1e6);
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
