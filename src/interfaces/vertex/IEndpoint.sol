// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.20;

interface IEndpoint {
    // events that we parse transactions into
    enum TransactionType {
        LiquidateSubaccount,
        DepositCollateral,
        WithdrawCollateral,
        SpotTick,
        UpdatePrice,
        SettlePnl,
        MatchOrders,
        DepositInsurance,
        ExecuteSlowMode,
        MintLp,
        BurnLp,
        SwapAMM,
        MatchOrderAMM,
        DumpFees,
        ClaimSequencerFees,
        PerpTick,
        ManualAssert,
        Rebate,
        UpdateProduct,
        LinkSigner,
        UpdateFeeRates,
        BurnLpAndTransfer
    }

    struct DepositCollateral {
        bytes32 sender;
        uint32 productId;
        uint128 amount;
    }

    struct WithdrawCollateral {
        bytes32 sender;
        uint32 productId;
        uint128 amount;
        uint64 nonce;
    }

    struct SlowModeTx {
        uint64 executableAt;
        address sender;
        bytes tx;
    }

    struct SlowModeConfig {
        uint64 timeout;
        uint64 txCount;
        uint64 txUpTo;
    }

    function getSlowModeTx(uint64)
        external
        view
        returns (SlowModeTx memory, uint64, uint64);

    function slowModeTxs(uint64 idx)
        external
        view
        returns (uint64, address, bytes calldata);

    function depositCollateral(
        bytes12 subaccountName,
        uint32 productId,
        uint128 amount
    )
        external;

    function submitSlowModeTransaction(bytes calldata transaction) external;
}
