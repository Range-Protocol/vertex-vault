// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.20;

interface IEndpoint {
    function depositCollateral(
        bytes12 subaccountName,
        uint32 productId,
        uint128 amount
    )
        external;

    function submitSlowModeTransaction(bytes calldata transaction) external;

    function getNonce(address sender) external view returns (uint64);
}
