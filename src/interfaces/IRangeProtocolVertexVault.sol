// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

interface IRangeProtocolVertexVault {
    event Minted(address user, uint256 shares, uint256 amount);
    event Burned(address user, uint256 shares, uint256 amount);
    event ProductAdded(uint256 product);
    event ProductRemoved(uint256 product);
    event ManagingFeeSet(uint256 managingFee);

    function mint(uint256 amount) external returns (uint256 shares);
    function burn(
        uint256 shares,
        uint256 minAmount
    )
        external
        returns (uint256 amount);
    function addProduct(uint256 productId) external;
    function removeProduct(uint256 productId) external;
    function multicallByManager(
        address[] calldata targets,
        bytes[] calldata data
    )
        external;
    function setManagingFee(uint256 _managingFee) external;
    function collectManagerFee() external;
    function getUnderlyingBalance() external view returns (uint256);
    function getPendingBalance()
        external
        view
        returns (uint256 pendingBalance);
    function getUnderlyingBalanceByShares(uint256 shares)
        external
        view
        returns (uint256 amount);
}
