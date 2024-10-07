// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script, console2 } from 'forge-std/Script.sol';

import { SkateVertexVault } from '../src/SkateVertexVault.sol';
import { ERC20 } from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract deployVault is Script {
    ERC20 USDC = ERC20(0x3894085Ef7Ff0f0aeDf52E2A2704928d1Ec074F1);
    SkateVertexVault vault = SkateVertexVault(0xD0f1ca95dd73ab608ce9fa2155E8e70f0f8885e0);

    function run() external {
        uint256 pk = vm.envUint('PK');
        vm.startBroadcast(pk);

        uint256 amount = 5 * 10 ** 6;
        uint256 minShares = 5 * 10 ** 18;
        USDC.approve(address(vault), amount);
//        vault.mint(amount, minShares);
        vm.stopBroadcast();
    }
}
