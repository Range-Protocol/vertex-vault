//// SPDX-License-Identifier: UNLICENSED
//pragma solidity 0.8.20;
//
//import { Test, console2 } from 'forge-std/Test.sol';
//import { IPyth } from 'pyth-sdk-solidity/IPyth.sol';
//import { PythStructs } from 'pyth-sdk-solidity/PythStructs.sol';
//
//contract TestPriceFeed is Test {
//    function setUp() external {
//        vm.createSelectFork(vm.rpcUrl('https://blast.din.dev/rpc'));
//    }
//
//    function testPrintPrice() external view {
//        IPyth pyth = IPyth(0xA2aa501b19aff244D90cc15a4Cf739D2725B5729);
//        bytes32 priceFeedId = 0x41283d3f78ccb459a24e5f1f1b9f5a72a415a26ff9ce0391a6878f4cda6b477b;
//        PythStructs.Price memory price = pyth.getPrice(priceFeedId);
//        console2.log(price.price);
//        console2.log(price.conf);
//        console2.log(price.expo);
//        console2.log(price.publishTime);
//    }
//}
