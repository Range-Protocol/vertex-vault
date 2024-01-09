// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

interface IPerpEngine {
    //    struct Balance {
    //        int128 amount;
    //        int128 lastCumulativeMultiplierX18;
    //    }

    //    struct Config {
    //        address token;
    //        int128 interestInflectionUtilX18;
    //        int128 interestFloorX18;
    //        int128 interestSmallCapX18;
    //        int128 interestLargeCapX18;
    //    }
    //
    //    function getBalance(
    //        uint32 productId,
    //        bytes32 subaccount
    //    ) external view returns (Balance memory);
    //
    //    function getConfig(uint32 productId) external view returns (Config
    // memory);

    function getPositionPnl(
        uint32 productId,
        bytes32 subaccount
    )
        external
        view
        returns (int128);
}
