// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import { Initializable } from
    '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import { UUPSUpgradeable } from
    '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import { ERC20Upgradeable } from
    '@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol';
import { ReentrancyGuardUpgradeable } from
    '@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol';
import { PausableUpgradeable } from
    '@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol';
import { Address } from '@openzeppelin/contracts/utils/Address.sol';
import { IERC20Metadata } from
    '@openzeppelin/contracts/interfaces/IERC20Metadata.sol';
import { IERC20 } from '@openzeppelin/contracts/interfaces/IERC20.sol';
import { SafeERC20 } from
    '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import { OwnableUpgradeable } from './access/OwnableUpgradeable.sol';
import { RangeProtocolVertexVaultStorage } from
    './RangeProtocolVertexVaultStorage.sol';
import { FullMath } from './libraries/FullMath.sol';
import { IPerpEngine } from './interfaces/vertex/IPerpEngine.sol';
import { ISpotEngine } from './interfaces/vertex/ISpotEngine.sol';
import { IEndpoint } from './interfaces/vertex/IEndpoint.sol';
import { VaultErrors } from './errors/VaultErrors.sol';

/**
 * @notice RangeProtocolVertexVault is a vault managed by the vault manager to
 * manage perpetual positions on Vertex protocol. It allows users to deposit
 * {depositToken} when opening a vault position and get vault shares that represent
 * their ownership of the vault. The vault manager is a linked signer of the
 * vault and can manage vault's assets off-chain to open long/short perpetual
 * positions on the vertex protocol.
 *
 * The LP ownership of the vault is represented by the fungible ERC20 token minted
 * by the vault to LPs.
 *
 * The vault manager is responsible to maintain a certain ratio of {depositToken} in
 * the vault as passive balance, so LPs can burn their vault shares and redeem the
 * underlying {depositToken} pro-rata to the amount of shares being burned.
 *
 * The LPs can burn their vault shares and redeem the underlying vault's {depositToken}
 * pro-rata to the amount of shares they are burning. The LPs pay managing fee on their
 * final redeemable amount.
 *
 * The LP token's price is based on total holding of the vault in {depositToken}.
 *  Holding of vault is calculated as sum of margin deposited, settled balance from
 * earlier perp positions and the PnL from the current opened perp positions.
 *
 * Manager can change the managing fee which is capped at maximum to 10% of the
 * redeemable amount by LP.
 *
 * Manager can add or remove (whitelist) the vertex-supported products in vault.
 */
contract RangeProtocolVertexVault is
    Initializable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    ERC20Upgradeable,
    PausableUpgradeable,
    RangeProtocolVertexVaultStorage
{
    using SafeERC20 for IERC20;
    using Address for address;

    uint256 public constant MAX_MANAGING_FEE = 1000;
    uint256 public constant X18_MULTIPLIER = 10 ** 18;

    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public pure override returns (string memory) {
        return 'Vertex Liquidity Vault';
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public pure override returns (string memory) {
        return 'R-VER';
    }

    /**
     * @notice initializes the vault.
     * @param _spotEngine address of {spotEngine} contract of Vertex Protocol.
     * @param _perpEngine address of {perpEngine} contract of Vertex Protocol.
     * @param _endpoint address of {endpoint} contract of Vertex Protocol.
     * @param _depositToken address of {depositToken} accepted as deposit asset
     * by the vault.
     * @param _manager address of vault's manager.
     * @param _name name of vault's ERC20 fungible token.
     * @param _symbol symbol of vault's ERC20 fungible token.
     */
    function initialize(
        ISpotEngine _spotEngine,
        IPerpEngine _perpEngine,
        IEndpoint _endpoint,
        IERC20 _depositToken,
        address _manager,
        string calldata _name,
        string calldata _symbol
    )
        external
        initializer
    {
        if (
            _perpEngine == IPerpEngine(address(0x0))
                || _spotEngine == ISpotEngine(address(0x0))
                || _endpoint == IEndpoint(address(0x0))
                || _depositToken == IERC20(address(0x0)) || _manager == address(0x0)
        ) {
            revert VaultErrors.ZeroAddress();
        }

        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        __Ownable_init();
        __ERC20_init(_name, _symbol);
        __Pausable_init();

        _transferOwnership(_manager);
        spotEngine = _spotEngine;
        perpEngine = _perpEngine;
        endpoint = _endpoint;
        depositToken = _depositToken;
        contractSubAccount = bytes32(uint256(uint160(address(this))) << 96);
        _setManagingFee(100); // set 1% as managing fee

        addProduct(4); // add ETH perp product
    }

    /**
     * @notice allows pausing of minting and burning features of the contract in the event
     * any security risk is seen in the vault.
     */
    function pause() external onlyManager {
        _pause();
    }

    /**
     * @notice allows unpausing of minting and burning features of the contract if they paused.
     */
    function unpause() external onlyManager {
        _unpause();
    }

    /**
     * @notice mints vault shares by depositing the {depositToken} amount.
     * @param amount the amount of {depositToken} to deposit.
     * @return shares the amount of vault shares minted.
     */
    function mint(uint256 amount)
        external
        override
        nonReentrant
        whenNotPaused
        returns (uint256 shares)
    {
        if (amount == 0) {
            revert VaultErrors.ZeroDepositAmount();
        }
        uint256 totalSupply = totalSupply();
        shares = totalSupply != 0
            ? FullMath.mulDivRoundingUp(amount, totalSupply, getUnderlyingBalance())
            : amount;

        if (shares == 0) revert VaultErrors.InvalidSharesAmount();
        _mint(msg.sender, shares);
        depositToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Minted(msg.sender, shares, amount);
    }

    /**
     * @notice allows burning of vault {shares} to redeem the underlying the {depositTokenBalance}.
     * @param shares the amount of shares to be burned by the user.
     * @param minAmount minimum amount to get from the user.
     * @return amount the amount of underlying {depositToken} to be redeemed by the user.
     */
    function burn(
        uint256 shares,
        uint256 minAmount
    )
        external
        override
        nonReentrant
        whenNotPaused
        returns (uint256 amount)
    {
        if (shares == 0) {
            revert VaultErrors.ZeroBurnAmount();
        }

        if (
            (
                amount = FullMath.mulDiv(
                    shares, getUnderlyingBalance(), totalSupply()
                )
            ) == 0
        ) {
            revert VaultErrors.ZeroAmountRedeemed();
        }
        _burn(msg.sender, shares);
        _applyManagingFee(amount);
        amount = _netManagingFee(amount);

        if (amount < minAmount) {
            revert VaultErrors.AmountIsLessThanMinAmount();
        }

        if (depositToken.balanceOf(address(this)) < amount) {
            revert VaultErrors.NotEnoughBalanceInVault();
        }

        depositToken.safeTransfer(msg.sender, amount);
        emit Burned(msg.sender, shares, amount);
    }

    /**
     * @notice allows manager to add new vertex protocol-supported products.
     * The productId is optimistically added to the list, the manager needs
     * to ensure the {productId} is valid on the Vertex Protocol.
     * @dev only manager can call it.
     * @param productId the id of the product to add.
     */
    function addProduct(uint256 productId) public override onlyManager {
        if (isWhiteListedProduct[productId]) {
            revert VaultErrors.ProductAlreadyWhitelisted();
        }
        isWhiteListedProduct[productId] = true;
        productIds.push(productId);
        emit ProductAdded(productId);
    }

    /**
     * @notice allows manager to remove products from the vault.
     * @dev only manager can call it.
     * @param productId the id of the product to remove.
     */
    function removeProduct(uint256 productId) external override onlyManager {
        if (!isWhiteListedProduct[productId]) {
            revert VaultErrors.ProductIsNotWhitelisted();
        }
        uint256 length = productIds.length;
        for (uint256 i = 0; i < length; i++) {
            if (productIds[i] == productId) {
                productIds[i] = productIds[length - 1];
                productIds.pop();
                delete isWhiteListedProduct[productId];
                emit ProductRemoved(productId);
                break;
            }
        }
    }

    /**
     * @notice allows manager to perform low-level calls to either the {depositToken}
     * contract for approvals or the {endpoint} contract to submit low-level transactions
     * to Vertex Protocol.
     * @param targets the list of {target} addresses to send the call-data to.
     * @param data the list of call-data to send to the correspondingly indexed {target}.
     * only manager can call this function.
     */
    function multicallByManager(
        address[] calldata targets,
        bytes[] calldata data
    )
        external
        override
        onlyManager
    {
        if (targets.length == 0 || targets.length != data.length) {
            revert VaultErrors.InvalidLength();
        }
        for (uint256 i = 0; i < targets.length; i++) {
            if (
                targets[i] == address(depositToken)
                    && (
                        bytes4(data[i][:4]) != depositToken.approve.selector
                            || address(uint160(uint256(bytes32(data[i][4:36]))))
                                != address(endpoint)
                    )
            ) {
                revert VaultErrors.InvalidApproveCall();
            }
            targets[i].functionCall(data[i]);
        }
    }

    /**
     * @notice allows manager to change managing fee.
     * @param _managingFee managingFee to set to.
     * only manager can call this function.
     */
    function setManagingFee(uint256 _managingFee)
        external
        override
        onlyManager
    {
        _setManagingFee(_managingFee);
    }

    /**
     * @notice allows manager to collect the fee.
     * only manager can call this function.
     */
    function collectManagerFee() external override onlyManager {
        uint256 _managerBalance = managerBalance;
        managerBalance = 0;
        depositToken.transfer(msg.sender, _managerBalance);
    }

    /**
     * @notice returns underlying vault holding in {depositToken}. The token precision of
     * underlying balance is in 18 decimals.
     * @dev the vault holding is calculated based on several amounts sources.
     * The amounts sources include passive {depositToken} balance in the
     * contract. The margin deposited on Vertex, settled balance on Vertex,
     * PnL from opened perp positions. All of this is summed up to represent
     * the vault holding in {depositToken}.
     * @return the total holding of the vault in USDC.
     */
    function getUnderlyingBalance() public view override returns (uint256) {
        uint256[] memory _productIds = productIds;
        bytes32 _contractSubAccount = contractSubAccount;
        int256 signedBalance =
            spotEngine.getBalance(0, _contractSubAccount).amount;

        for (uint256 i = 0; i < _productIds.length; i++) {
            signedBalance += perpEngine.getPositionPnl(
                uint32(_productIds[i]), _contractSubAccount
            );
        }

        // We optimistically assume that managerBalance will always be part of passive balance
        // but in the event, it is not there, we add this check to avoid the underflow.
        uint256 passiveBalance = depositToken.balanceOf(address(this));
        if (passiveBalance > managerBalance) {
            passiveBalance -= managerBalance;
        }

        return _toXTokenDecimals(uint256(signedBalance)) + passiveBalance
            + getPendingBalance();
    }

    /**
     * @notice getting pending balance from vertex.
     * It checks all the queued transaction and fetched the deposit transactions
     * sent by the vault and calculate pending balance from it.
     * @return pendingBalance the pending balance amount.
     */
    function getPendingBalance()
        public
        view
        override
        returns (uint256 pendingBalance)
    {
        (, uint64 txUpTo, uint64 txCount) = endpoint.getSlowModeTx(0);
        for (uint64 i = txUpTo; i < txCount; i++) {
            (IEndpoint.SlowModeTx memory slowMode,,) = endpoint.getSlowModeTx(i);
            if (slowMode.sender != address(this)) continue;

            (uint8 txType, bytes memory payload) = this.decodeTx(slowMode.tx);
            if (txType == uint8(IEndpoint.TransactionType.DepositCollateral)) {
                IEndpoint.DepositCollateral memory depositPayload =
                    abi.decode(payload, (IEndpoint.DepositCollateral));
                if (depositPayload.productId == 0) {
                    pendingBalance += uint256(depositPayload.amount);
                }
            }
        }
    }

    function decodeTx(bytes calldata transaction)
        public
        pure
        returns (uint8, bytes memory)
    {
        return (uint8(transaction[0]), transaction[1:]);
    }

    /**
     * @notice returns the underlying balance redeemable by the provided amounts of {shares}.
     * @param shares the amounts of shares to calculate the underlying balance against.
     * @return amount the amount of underlying balance redeemable against the provided
     * amount of shares.
     */
    function getUnderlyingBalanceByShares(uint256 shares)
        external
        view
        override
        returns (uint256 amount)
    {
        uint256 _totalSupply = totalSupply();
        if (_totalSupply != 0) {
            if (shares > _totalSupply) {
                revert VaultErrors.InvalidShareAmount();
            }

            amount = shares * getUnderlyingBalance() / _totalSupply;
            amount = _netManagingFee(amount);
        }
    }

    /**
     * @notice sets managing fee to a maximum of {MAX_MANAGING_FEE}.
     */
    function _setManagingFee(uint256 _managingFee) private {
        if (_managingFee > MAX_MANAGING_FEE) {
            revert VaultErrors.InvalidManagingFee();
        }
        managingFee = _managingFee;

        emit ManagingFeeSet(_managingFee);
    }

    /**
     * @notice subtracts managing fee from the redeemable {amount}.
     * @return amountAfterFee the {depositToken} amount redeemable after
     * the managing fee is deducted.
     */
    function _netManagingFee(uint256 amount)
        private
        view
        returns (uint256 amountAfterFee)
    {
        amountAfterFee = amount - ((amount * managingFee) / 10_000);
    }

    /**
     * @notice add managing fee to the manager collectable balance.
     * @param amount the amount of apply managing fee upon.
     */
    function _applyManagingFee(uint256 amount) private {
        managerBalance += (amount * managingFee) / 10_000;
    }

    /**
     * @notice internal function guard against upgrading the vault
     * implementation by non-manager.
     */
    function _authorizeUpgrade(address) internal view override {
        require(msg.sender == manager());
    }

    /**
     * @notice convert amount X18 amount to the decimal precision of {depositToken}
     */
    function _toXTokenDecimals(uint256 amountX18)
        private
        view
        returns (uint256 amountXTokenDecimals)
    {
        amountXTokenDecimals = (
            amountX18 * 10 ** IERC20Metadata(address(depositToken)).decimals()
        ) / X18_MULTIPLIER;
    }
}
