// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;
import { Test, console2 } from 'forge-std/Test.sol';

import { Initializable } from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import { UUPSUpgradeable } from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import { ERC20Upgradeable } from '@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol';
import { ReentrancyGuardUpgradeable } from '@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol';
import { PausableUpgradeable } from '@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol';
import { Address } from '@openzeppelin/contracts/utils/Address.sol';
import { IERC20Metadata } from '@openzeppelin/contracts/interfaces/IERC20Metadata.sol';
import { IERC20 } from '@openzeppelin/contracts/interfaces/IERC20.sol';
import { SafeERC20 } from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import { OwnableUpgradeable } from './access/OwnableUpgradeable.sol';
import { RangeProtocolVertexVaultStorage } from './RangeProtocolVertexVaultStorage.sol';
import { FullMath } from './libraries/FullMath.sol';
import { IPerpEngine } from './interfaces/vertex/IPerpEngine.sol';
import { ISpotEngine } from './interfaces/vertex/ISpotEngine.sol';
import { IEndpoint } from './interfaces/vertex/IEndpoint.sol';
import { VaultErrors } from './errors/VaultErrors.sol';

/**
 * @dev RangeProtocolVertexVault is a vault managed by the vault manager to
 * manage perpetual positions on Vertex protocol. It allows users to deposit
 * {usdb} when opening a vault position and get vault shares that represent
 * their ownership of the vault. The vault manager is a linked signer of the
 * vault and can manage vault's assets off-chain to open long/short perpetual
 * positions on the vertex protocol.
 *
 * The LP ownership of the vault is represented by the fungible ERC20 token minted
 * by the vault to LPs.
 *
 * The vault manager is responsible to maintain a certain ratio of {usdb} in
 * the vault as passive balance, so LPs can burn their vault shares and redeem the
 * underlying {usdb} pro-rata to the amount of shares being burned.
 *
 * The LPs can burn their vault shares and redeem the underlying vault's {usdb}
 * pro-rata to the amount of shares they are burning. The LPs pay managing fee on their
 * final redeemable amount.
 *
 * The LP token's price is based on total holding of the vault in {usdb}.
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

    modifier onlyUpgrader() {
        if (msg.sender != upgrader) revert VaultErrors.OnlyUpgraderAllowed();
        _;
    }

    constructor() {
        _disableInitializers();
    }

    /**
     * @dev initializes the vault.
     * by the vault.
     * @param _manager address of vault's manager.
     * @param _name name of vault's ERC20 fungible token.
     * @param _symbol symbol of vault's ERC20 fungible token.
     * @param _upgrader the address of the upgrader
     */
    function initialize(
        address _manager,
        address _upgrader,
        string calldata _name,
        string calldata _symbol
    )
        external
        initializer
    {
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        __Ownable_init();
        __ERC20_init(_name, _symbol);
        __Pausable_init();

        addProduct(4); // add ETH perp product
        _transferOwnership(_manager);

        spotEngine = ISpotEngine(0x57c1AB256403532d02D1150C5790423967B22Bf2);
        perpEngine = IPerpEngine(0x0bc0c84976e21aaF7bE71d318eD93A5f5c9978A4);
        endpoint = IEndpoint(0x00F076FE36f2341A1054B16ae05FcE0C65180DeD);
        upgrader = _upgrader;
        usdb = IERC20(0x4300000000000000000000000000000000000003);

        contractSubAccount = bytes32(uint256(uint160(address(this))) << 96);
        _setManagingFee(25); // set 0.25% as managing fee

        whitelistedTargets[address(usdb)] = true;
        targets.push(address(usdb));
        emit TargetAddedToWhitelist(address(usdb));

        // whitelist endpoint contract to allow manager to deposit and withdraw assets to and from Vertex using
        // multicallByManager function.
        whitelistedTargets[address(endpoint)] = true;
        targets.push(address(endpoint));
        emit TargetAddedToWhitelist(address(endpoint));
    }

    //    /**
    //     * @dev only will be called once to set the new state of the vault according to the new implementation
    //     */
    //    function reinit() external onlyManager {
    //        require(upgrader == address(0x0)); // check ensure manager can call it only once.
    //        // timelock address which can upgrade the vault.
    //        upgrader = 0x75a45Bc069F345b424dc67fb37d7079e219AF206;
    //
    //        // wETH and wBTC addresses that we expect to have as passive balance in the vault after swapping
    //        // vault's usdb to wETH and wBTC.
    //        wETH = IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    //        wBTC = IERC20(0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f);
    //
    //        // whitelist usdb so we could call approve function on the contract in multicallByManager function.
    //        whitelistedTargets[address(usdb)] = true;
    //        targets.push(address(usdb));
    //        emit TargetAddedToWhitelist(address(usdb));
    //
    //        // whitelist endpoint contract to allow manager to deposit and withdraw assets to and from Vertex using
    //        // multicallByManager function.
    //        whitelistedTargets[address(endpoint)] = true;
    //        targets.push(address(endpoint));
    //        emit TargetAddedToWhitelist(address(endpoint));
    //
    //        // whitelisting native router, so this router could be called in swap function to perform swap between assets.
    //        address nativeRouter = 0xEAd050515E10fDB3540ccD6f8236C46790508A76;
    //        whitelistedSwapRouters[nativeRouter] = true;
    //        swapRouters.push(nativeRouter);
    //        emit SwapRouterAddedToWhitelist(nativeRouter);
    //
    //        minimumSwapInterval = 15 minutes;
    //        swapThreshold = 9995;
    //
    //        // set the price oracles for the vault's assets.
    ////        tokenToPriceOracle[usdb] = AggregatorV3Interface(0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3);
    ////        tokenToPriceOracle[wETH] = AggregatorV3Interface(0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612);
    ////        tokenToPriceOracle[wBTC] = AggregatorV3Interface(0xd0C7101eACbB49F3deCcCc166d238410D6D46d57);
    //    }

    /**
     * @dev mints vault shares by depositing the {usdb} amount.
     * @param amount the amount of {usdb} to deposit.
     * @return shares the amount of vault shares minted.
     * requirements
     * - amount to deposit must not be zero.
     * - pending balance must not be zero i.e. there are no funds in transit from vault to vertex.
     * - shares to be minted to the user be more or equaling {minShares}.
     */
    function mint(
        uint256 amount,
        uint256 minShares
    )
        external
        override
        nonReentrant
        whenNotPaused
        returns (uint256 shares)
    {
        if (amount == 0) revert VaultErrors.ZeroDepositAmount();
        if (getPendingBalance() != 0) revert VaultErrors.MintNotAllowed();
        uint256 totalSupply = totalSupply();
        shares = totalSupply != 0 ? FullMath.mulDivRoundingUp(amount, totalSupply, getUnderlyingBalance()) : amount;

        if (shares < minShares) revert VaultErrors.InvalidSharesAmount();
        _mint(msg.sender, shares);
        usdb.safeTransferFrom(msg.sender, address(this), amount);
        emit Minted(msg.sender, shares, amount);
    }

    /**
     * @dev allows burning of vault {shares} to redeem the underlying the {usdbBalance}.
     * @param shares the amount of shares to be burned by the user.
     * @param minAmount minimum amount to get from the user.
     * @return amount the amount of underlying {usdb} to be redeemed by the user.
     * requirements
     * - shares to redeem must not be zero.
     * - pending balance must not be zero i.e. there are no funds in transit from vault to vertex.
     * - the resultant amount from shares redemption must not be zero or less than {minAmount} and the vault
     * must have the passive balance more or equalling resultant amount.
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
        if (shares == 0) revert VaultErrors.ZeroBurnAmount();
        if (getPendingBalance() != 0) revert VaultErrors.BurnNotAllowed();

        if ((amount = FullMath.mulDiv(shares, getUnderlyingBalance(), totalSupply())) == 0) {
            revert VaultErrors.ZeroAmountRedeemed();
        }
        _burn(msg.sender, shares);
        _applyManagingFee(amount);
        amount = _netManagingFee(amount);

        if (amount < minAmount) revert VaultErrors.AmountIsLessThanMinAmount();
        if (usdb.balanceOf(address(this)) < amount) revert VaultErrors.NotEnoughBalanceInVault();
        usdb.safeTransfer(msg.sender, amount);
        emit Burned(msg.sender, shares, amount);
    }

    /**
     * @dev allows manager to perform low-level calls to the whitelisted target addresses.
     * @param targets the list of {target} addresses to send the call-data to.
     * @param data the list of call-data to send to the correspondingly indexed {target}.
     * requirements
     * - only manager can call this function.
     * - the length of targets and data must be same and not zero.
     * - the target must be a whitelisted address.
     * - if the target is {usdb} then only approve call is allows with approval to endpoint contract.
     */
    function multicallByManager(address[] calldata targets, bytes[] calldata data) external override onlyManager {
        if (targets.length == 0 || targets.length != data.length) revert VaultErrors.InvalidLength();
        for (uint256 i = 0; i < targets.length; i++) {
            if (!whitelistedTargets[targets[i]]) revert VaultErrors.TargetIsNotWhitelisted();
            if (
                targets[i] == address(usdb)
                    && (
                        bytes4(data[i][:4]) != usdb.approve.selector
                            || address(uint160(uint256(bytes32(data[i][4:36])))) != address(endpoint)
                    )
            ) revert VaultErrors.InvalidMulticall();

            // performs check that only the tx types of WithdrawCollateral and LinkSigner are allowed on the endpoint
            // when calling the submitSlowModeTransaction on endpoint contract.
            if (
                targets[i] == address(endpoint)
                    && (
                        bytes4(data[i][:4]) == endpoint.submitSlowModeTransaction.selector
                            && (
                                IEndpoint.TransactionType(uint8(bytes1(data[i][68:69])))
                                    != IEndpoint.TransactionType.WithdrawCollateral
                                    && IEndpoint.TransactionType(uint8(bytes1(data[i][68:69])))
                                        != IEndpoint.TransactionType.LinkSigner
                            )
                    )
            ) revert VaultErrors.InvalidMulticall();
            targets[i].functionCall(data[i]);
        }
    }

    /**
     * @dev allows pausing of minting and burning features of the contract in the event
     * any security risk is seen in the vault.
     * requirements
     * - only manager can call this function.
     */
    function pause() external onlyManager {
        _pause();
    }

    /**
     * @dev allows unpausing of minting and burning features of the contract if they paused.
     * requirements
     * - only manager can call this function.
     */
    function unpause() external onlyManager {
        _unpause();
    }

    /**
     * @dev allows manager to change managing fee.
     * @param _managingFee managingFee to set to.
     * requirements
     * - only manager can call this function.
     */
    function setManagingFee(uint256 _managingFee) external override onlyManager {
        _setManagingFee(_managingFee);
    }

    /**
     * @dev allows manager to collect the fee.
     * requirements
     * - only manager can call this function.
     */
    function collectManagerFee() external override onlyManager {
        uint256 _managerBalance = managerBalance;
        managerBalance = 0;
        usdb.transfer(msg.sender, _managerBalance);
    }

    /**
     * @dev allows manager to add new vertex protocol-supported products.
     * The productId is optimistically added to the list, the manager needs
     * to ensure the {productId} is valid on the Vertex Protocol.
     * @param productId the id of the product to add.
     * requirements
     * - only manager can call it.
     * - the product must not be whitelisted already.
     */
    function addProduct(uint256 productId) public override onlyManager {
        if (isWhiteListedProduct[productId]) revert VaultErrors.ProductAlreadyWhitelisted();
        isWhiteListedProduct[productId] = true;
        productIds.push(productId);
        emit ProductAdded(productId);
    }

    /**
     * @dev allows manager to remove products from the vault.
     * @param productId the id of the product to remove.
     * requirements
     * - only upgrader can call this function.
     * - the product must whitelisted already.
     */
    function removeProduct(uint256 productId) external override onlyUpgrader {
        if (!isWhiteListedProduct[productId]) revert VaultErrors.ProductIsNotWhitelisted();
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
     * @dev changeUpgrader changes the upgrader of the vault.
     * @param newUpgrader the new upgrader of the vault.
     * requirements
     * - the new upgrader cannot be a zero address.
     * - only current upgrader can call this function.
     */
    function changeUpgrader(address newUpgrader) external onlyUpgrader {
        if (newUpgrader == address(0x0)) revert VaultErrors.ZeroAddress();
        upgrader = newUpgrader;
    }

    /**
     * @dev whiteListTarget allows whitelisting the target address that can be called by the vault through multicallByManager
     * function.
     * @param target the address to add to the targets whitelist.
     * requirements
     * - only upgrader can call this function.
     * - the target address must not be already whitelisted.
     */
    function whiteListTarget(address target) external onlyUpgrader {
        if (whitelistedTargets[target]) revert VaultErrors.TargetIsWhitelisted();

        whitelistedTargets[target] = true;
        targets.push(target);

        emit TargetAddedToWhitelist(target);
    }

    /**
     * @dev removeTargetFromWhitelist allows removing of target address from the whitelist.
     * @param target the adddress to remove from the targets whitelist.
     * requirements
     * - only upgrader can call this function.
     * - the target address must be already whitelisted.
     */
    function removeTargetFromWhitelist(address target) external onlyUpgrader {
        if (!whitelistedTargets[target]) revert VaultErrors.TargetIsNotWhitelisted();

        whitelistedTargets[target] = false;
        uint256 length = targets.length;
        for (uint256 i = 0; i < length; i++) {
            if (targets[i] == target) {
                targets[i] = targets[length - 1];
                targets.pop();
                delete whitelistedTargets[target];
                emit TargetRemovedFromWhitelist(target);
                break;
            }
        }
    }

    /**
     * @dev getMintAmount returns the amount of vault shares user gets upon depositing the {depositAmount} of usdb.
     * @param depositAmount the amount of usdb to deposit.
     */
    function getMintAmount(uint256 depositAmount) external view override returns (uint256) {
        return FullMath.mulDivRoundingUp(depositAmount, totalSupply(), getUnderlyingBalance());
    }

    /**
     * @dev returns the underlying balance redeemable by the provided amounts of {shares}.
     * @param shares the amounts of shares to calculate the underlying balance against.
     * @return amount the amount of underlying balance redeemable against the provided
     * amount of shares.
     */
    function getUnderlyingBalanceByShares(uint256 shares) external view override returns (uint256 amount) {
        uint256 _totalSupply = totalSupply();
        if (_totalSupply != 0) {
            if (shares > _totalSupply) revert VaultErrors.InvalidShareAmount();

            amount = shares * getUnderlyingBalance() / _totalSupply;
            amount = _netManagingFee(amount);
        }
    }

    /**
     * @dev returns underlying vault holding in {usdb}. The vault holding represents passive usdb, wBTC and wETH in the vault
     * along with any PnL from the whitelisted perp products on the Vertex protocol.
     * @return the total holding of the vault in usdb.
     */
    function getUnderlyingBalance() public view override returns (uint256) {
        uint256[] memory _productIds = productIds;
        bytes32 _contractSubAccount = contractSubAccount;

        // get usdb margin balance + any settled amounts from trades.
        int256 signedBalance = spotEngine.getBalance(0, _contractSubAccount).amount;

        // get PnL balance from all perp products.
        for (uint256 i = 0; i < _productIds.length; i++) {
            signedBalance += perpEngine.getPositionPnl(uint32(_productIds[i]), _contractSubAccount);
        }

        // should never happen as the account would be liquidated below maintenance margin.
        if (signedBalance < 0) revert VaultErrors.VaultIsUnderWater();
        uint256 passiveBalance = usdb.balanceOf(address(this));

        // We optimistically assume that managerBalance will always be part of passive balance
        // but in the event, it is not there, we add this check to avoid the underflow.
        if (passiveBalance >= managerBalance) passiveBalance -= managerBalance;
        console2.log("passive balance: ", passiveBalance);
        console2.log("pending balance: ", getPendingBalance());
        return _toXTokenDecimals(uint256(signedBalance)) + passiveBalance + getPendingBalance();
    }

    /**
     * @dev getting pending balance from vertex.
     * It checks all the queued transaction and fetched the deposit transactions
     * sent by the vault and calculate pending balance from it.
     * @return pendingBalance the pending balance amount.
     */
    function getPendingBalance() public view override returns (uint256 pendingBalance) {
        (, uint64 txUpTo, uint64 txCount) = endpoint.getSlowModeTx(0);
        for (uint64 i = txUpTo; i < txCount; i++) {
            (IEndpoint.SlowModeTx memory slowMode,,) = endpoint.getSlowModeTx(i);
            if (slowMode.sender != address(this)) continue;

            (uint8 txType, bytes memory payload) = this.decodeTx(slowMode.tx);
            if (txType == uint8(IEndpoint.TransactionType.DepositCollateral)) {
                IEndpoint.DepositCollateral memory depositPayload = abi.decode(payload, (IEndpoint.DepositCollateral));
                if (depositPayload.productId == 0) pendingBalance += uint256(depositPayload.amount);
            }
        }
    }

    /**
     * @dev utility function to slice the transaction data.
     */
    function decodeTx(bytes calldata transaction) public pure returns (uint8, bytes memory) {
        return (uint8(transaction[0]), transaction[1:]);
    }

    /**
     * @dev sets managing fee to a maximum of {MAX_MANAGING_FEE}.
     * requirements
     * - _managingFee must not exceed {MAX_MANAGING_FEE}
     */
    function _setManagingFee(uint256 _managingFee) private {
        if (_managingFee > MAX_MANAGING_FEE) revert VaultErrors.InvalidManagingFee();
        managingFee = _managingFee;

        emit ManagingFeeSet(_managingFee);
    }

    /**
     * @dev subtracts managing fee from the redeemable {amount}.
     * @return amountAfterFee the {usdb} amount redeemable after
     * the managing fee is deducted.
     */
    function _netManagingFee(uint256 amount) private view returns (uint256 amountAfterFee) {
        amountAfterFee = amount - ((amount * managingFee) / 10_000);
    }

    /**
     * @dev add managing fee to the manager collectable balance.
     * @param amount the amount of apply managing fee upon.
     */
    function _applyManagingFee(uint256 amount) private {
        managerBalance += (amount * managingFee) / 10_000;
    }

    /**
     * @dev internal function guard against upgrading the vault
     * implementation by non-manager.
     */
    function _authorizeUpgrade(address) internal view override onlyUpgrader { }

    /**
     * @dev convert amount X18 amount to the decimal precision of {usdb}
     */
    function _toXTokenDecimals(uint256 amountX18) private view returns (uint256 amountXTokenDecimals) {
        amountXTokenDecimals = (amountX18 * 10 ** IERC20Metadata(address(usdb)).decimals()) / X18_MULTIPLIER;
    }
}
