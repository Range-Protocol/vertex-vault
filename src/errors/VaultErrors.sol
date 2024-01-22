// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

library VaultErrors {
    error ZeroAddress();
    error NotEnoughBalanceInVault();
    error ZeroDepositAmount();
    error ZeroBurnAmount();
    error ProductAlreadyWhitelisted();
    error ProductIsNotWhitelisted();
    error ZeroAmountRedeemed();
    error InvalidManagingFee();
    error InvalidLength();
    error InvalidMulticallTarget();
    error InvalidApproveCall();
    error InvalidShareAmount();
    error VaultIsUnderWater();
    error AmountIsLessThanMinAmount();
}
