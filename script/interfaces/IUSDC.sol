// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IUSDC {
    function mint(address, uint256) external;
    function approve(address, uint256) external;
    function transfer(address, uint256) external;
}
