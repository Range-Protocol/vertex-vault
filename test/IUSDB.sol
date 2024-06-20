// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

interface IUSDB {
    function mint(address, uint256) external;
    function approve(address, uint256) external;
    function transfer(address, uint256) external;
    function balanceOf(address) external view returns (uint256);
}
