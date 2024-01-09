// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

interface ISpotEngine {
    struct Balance {
        int128 amount;
        int128 lastCumulativeMultiplierX18;
    }

    function getBalance(
        uint32 productId,
        bytes32 subaccount
    )
        external
        view
        returns (Balance memory);
}
