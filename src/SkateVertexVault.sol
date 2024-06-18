// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

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
import { AggregatorV3Interface } from '@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol';
import { SkateVertexVaultStorage } from './SkateVertexVaultStorage.sol';
import { FullMath } from './libraries/FullMath.sol';
import { IPerpEngine } from './interfaces/vertex/IPerpEngine.sol';
import { ISpotEngine } from './interfaces/vertex/ISpotEngine.sol';
import { IEndpoint } from './interfaces/vertex/IEndpoint.sol';
import { VaultErrors } from './errors/VaultErrors.sol';

/**
 * @dev SkateVertexVault.sol is a vault managed by the vault manager to
 * manage perpetual positions on Vertex protocol. It allows users to deposit
 * {usdc} when opening a vault position and get vault shares that represent
 * their ownership of the vault. The vault manager is a linked signer of the
 * vault and can manage vault's assets off-chain to open long/short perpetual
 * positions on the vertex protocol.
 *
 * The LP ownership of the vault is represented by the fungible ERC20 token minted
 * by the vault to LPs.
 *
 * The vault manager is responsible to maintain a certain ratio of {usdc} in
 * the vault as passive balance, so LPs can burn their vault shares and redeem the
 * underlying {usdc} pro-rata to the amount of shares being burned.
 *
 * The LPs can burn their vault shares and redeem the underlying vault's {usdc}
 * pro-rata to the amount of shares they are burning. The LPs pay managing fee on their
 * final redeemable amount.
 *
 * The LP token's price is based on total holding of the vault in {usdc}.
 *  Holding of vault is calculated as sum of margin deposited, settled balance from
 * earlier perp positions and the PnL from the current opened perp positions.
 *
 * Manager can change the managing fee which is capped at maximum to 10% of the
 * redeemable amount by LP.
 *
 * Manager can add or remove (whitelist) the vertex-supported products in vault.
 */
contract SkateVertexVault is
    Initializable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    ERC20Upgradeable,
    PausableUpgradeable,
    SkateVertexVaultStorage
{
    using SafeERC20 for IERC20;
    using Address for address;

    uint256 public constant MAX_MANAGING_FEE = 1000;
    int256 public constant X18_MULTIPLIER = 10 ** 18;
    uint256 public constant DECIMALS_DIFFERENCE_MULTIPLIER = 10 ** 12;

    modifier onlyUpgrader() {
        if (msg.sender != upgrader) revert VaultErrors.OnlyUpgraderAllowed();
        _;
    }

    constructor() {
        _disableInitializers();
    }

    /**
     * @dev initializes the vault.
     * @param _spotEngine address of {spotEngine} contract of Vertex Protocol.
     * @param _perpEngine address of {perpEngine} contract of Vertex Protocol.
     * @param _endpoint address of {endpoint} contract of Vertex Protocol.
     * @param _usdc address of {usdc} accepted as deposit asset
     * by the vault.
     * @param _manager address of vault's manager.
     * @param _name name of vault's ERC20 fungible token.
     * @param _symbol symbol of vault's ERC20 fungible token.
     * @param _upgrader the address of the upgrader
     */
    function initialize(
        ISpotEngine _spotEngine,
        IPerpEngine _perpEngine,
        IEndpoint _endpoint,
        IERC20 _usdc,
        address _manager,
        string calldata _name,
        string calldata _symbol,
        address _upgrader
    )
        external
        initializer
    {
        if (
            _perpEngine == IPerpEngine(address(0x0)) || _spotEngine == ISpotEngine(address(0x0))
                || _endpoint == IEndpoint(address(0x0)) || _usdc == IERC20(address(0x0)) || _manager == address(0x0)
        ) revert VaultErrors.ZeroAddress();

        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        __Ownable_init();
        __ERC20_init(_name, _symbol);
        __Pausable_init();

        spotEngine = _spotEngine;
        perpEngine = _perpEngine;
        endpoint = _endpoint;
        usdc = _usdc;
        contractSubAccount = bytes32(uint256(uint160(address(this))) << 96);
        _setManagingFee(100); // set 1% as managing fee
        upgrader = _upgrader;

        addProduct(0);
        addProduct(1);
        addProduct(2);
        addProduct(3);
        addProduct(4);

        IERC20 wETH = IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
        IERC20 wBTC = IERC20(0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f);

        // add usdc as asset.
        _addAsset(
            _usdc,
            AssetData({
                idx: 0,
                spotId: 0,
                perpId: 0,
                priceFeed: AggregatorV3Interface(0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3),
                heartbeat: 86_400 + 1800
            })
        );

        // add wETH as asset.
        _addAsset(
            wETH,
            AssetData({
                idx: 0,
                spotId: 3,
                perpId: 4,
                priceFeed: AggregatorV3Interface(0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612),
                heartbeat: 86_400 + 1800
            })
        );

        // add wBTC as asset.
        _addAsset(
            wBTC,
            AssetData({
                idx: 0,
                spotId: 1,
                perpId: 2,
                priceFeed: AggregatorV3Interface(0xd0C7101eACbB49F3deCcCc166d238410D6D46d57),
                heartbeat: 86_400 + 1800
            })
        );

        // whitelist USDC so we could call approve function on the contract in multicallByManager function.
        whitelistedTargets[address(usdc)] = true;
        targets.push(address(usdc));
        emit TargetAddedToWhitelist(address(usdc));

        whitelistedTargets[address(wETH)] = true;
        targets.push(address(wETH));
        emit TargetAddedToWhitelist(address(wETH));

        whitelistedTargets[address(wBTC)] = true;
        targets.push(address(wBTC));
        emit TargetAddedToWhitelist(address(wBTC));

        // whitelist endpoint contract to allow manager to deposit and withdraw assets to and from Vertex using
        // multicallByManager function.
        whitelistedTargets[address(endpoint)] = true;
        targets.push(address(endpoint));
        emit TargetAddedToWhitelist(address(endpoint));

        // whitelisting native router, so this router could be called in swap function to perform swap between assets.
        address nativeRouter = 0xEAd050515E10fDB3540ccD6f8236C46790508A76;
        whitelistedSwapRouters[nativeRouter] = true;
        swapRouters.push(nativeRouter);
        emit SwapRouterAddedToWhitelist(nativeRouter);
        swapThreshold = 9995;

        _transferOwnership(_manager);
    }

    /**
     * @dev mints vault shares by depositing the {usdc} amount.
     * @param amount the amount of {usdc} to deposit.
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
        uint256 totalSupply = totalSupply();
        shares = totalSupply != 0
            ? FullMath.mulDivRoundingUp(amount, totalSupply, getUnderlyingBalance())
            : amount * DECIMALS_DIFFERENCE_MULTIPLIER;

        if (shares < minShares) revert VaultErrors.InvalidSharesAmount();
        _mint(msg.sender, shares);
        usdc.safeTransferFrom(msg.sender, address(this), amount);
        emit Minted(msg.sender, shares, amount);
    }

    /**
     * @dev allows burning of vault {shares} to redeem the underlying the {usdcBalance}.
     * @param shares the amount of shares to be burned by the user.
     * @param minAmount minimum amount to get from the user.
     * @return amount the amount of underlying {usdc} to be redeemed by the user.
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
        if ((amount = FullMath.mulDiv(shares, getUnderlyingBalance(), totalSupply())) == 0) {
            revert VaultErrors.ZeroAmountRedeemed();
        }
        _burn(msg.sender, shares);
        _applyManagingFee(amount);
        amount = _netManagingFee(amount);

        if (amount < minAmount) revert VaultErrors.AmountIsLessThanMinAmount();
        if (usdc.balanceOf(address(this)) < amount) revert VaultErrors.NotEnoughBalanceInVault();
        usdc.safeTransfer(msg.sender, amount);
        emit Burned(msg.sender, shares, amount);
    }

    /**
     * @dev swap function to swap the vault's assets. Calls the calldata on whitelisted swap router.
     * @param target the whitelisted address of the swap router.
     * @param swapData the calldata for the swap.
     * @param tokenIn the address of the token to be swapped.
     * @param amountIn the amount of the swapped token.
     * requirements
     * - only manager can call it.
     * - the {target} address must be a whitelisted swap router.
     * - the call to swap function must satisfy the minimum swap interval.
     * - the ratio of underlying vault's balance before and after the swap must not fall below the swap threshold.
     */
    function swap(address target, bytes calldata swapData, IERC20 tokenIn, uint256 amountIn) external onlyManager {
        // the swap router must be whitelisted.
        if (!whitelistedSwapRouters[target]) revert VaultErrors.SwapRouterIsNotWhitelisted();

        // cache the balances of the vault before swap.
        IERC20[] memory _assets = assets;
        uint256[] memory balancesBefore = new uint256[](assets.length);
        for (uint256 i = 0; i < _assets.length; i++) {
            balancesBefore[i] = _assets[i].balanceOf(address(this));
        }

        uint256 underlyingBalanceBefore = getUnderlyingBalance();

        // perform swap
        tokenIn.forceApprove(target, amountIn);
        Address.functionCall(target, swapData);
        tokenIn.forceApprove(target, 0);

        // get underlying balance of the vault after swap.
        uint256[] memory balancesAfter = new uint256[](_assets.length);
        for (uint256 i = 0; i < _assets.length; i++) {
            balancesAfter[i] = _assets[i].balanceOf(address(this));
        }
        uint256 underlyingBalanceAfter = getUnderlyingBalance();

        // revert the transaction if the ratio between underlying balance of the vault before and after the swap falls
        // below a the specified swap threshold.
        if ((underlyingBalanceAfter * 10_000 / underlyingBalanceBefore) < swapThreshold) {
            revert VaultErrors.SwapThresholdExceeded();
        }

        IERC20 tokenOut;
        uint256 amountOut;
        for (uint256 i = 0; i < _assets.length; i++) {
            if (balancesAfter[i] > balancesBefore[i]) {
                tokenOut = _assets[i];
                amountOut = balancesAfter[i] - balancesBefore[i];
                break;
            }
        }

        if (tokenOut == IERC20(address(0x0)) || amountOut == 0) revert VaultErrors.IncorrectSwap();

        emit Swapped(tokenIn, amountIn, tokenOut, amountOut, block.timestamp);
    }

    /**
     * @dev allows manager to perform low-level calls to the whitelisted target addresses.
     * @param targets the list of {target} addresses to send the call-data to.
     * @param data the list of call-data to send to the correspondingly indexed {target}.
     * requirements
     * - only manager can call this function.
     * - the length of targets and data must be same and not zero.
     * - the target must be a whitelisted address.
     * - if the target is {usdc} then only approve call is allows with approval to endpoint contract.
     */
    function multicallByManager(address[] calldata targets, bytes[] calldata data) external override onlyManager {
        if (targets.length == 0 || targets.length != data.length) revert VaultErrors.InvalidLength();
        for (uint256 i = 0; i < targets.length; i++) {
            if (!whitelistedTargets[targets[i]]) revert VaultErrors.TargetIsNotWhitelisted();
            if (
                assetsData[IERC20(targets[i])].heartbeat != 0 // if target is an asset
                    && (
                        bytes4(data[i][:4]) != IERC20.approve.selector
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
        usdc.transfer(msg.sender, _managerBalance);
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
    function changeUpgrader(address newUpgrader) external override onlyUpgrader {
        if (newUpgrader == address(0x0)) revert VaultErrors.ZeroAddress();
        upgrader = newUpgrader;
    }

    /**
     * @dev whiteListSwapRouter allows whitelisting a swap router address.
     * @param swapRouter the address of the swap router.
     * requirements
     * - only upgrader can call this function
     * - the swap router must not be already whitelisted.
     */
    function whiteListSwapRouter(address swapRouter) external override onlyUpgrader {
        if (whitelistedSwapRouters[swapRouter]) revert VaultErrors.SwapRouterIsWhitelisted();

        whitelistedSwapRouters[swapRouter] = true;
        swapRouters.push(swapRouter);

        emit SwapRouterAddedToWhitelist(swapRouter);
    }

    /**
     * @dev removeSwapRouterFromWhitelist removes swap router from the whitelist of swap routers.
     * @param swapRouter the address of the swapRouter to remove from whitelist.
     * requirements
     * - only upgrader can call this function.
     * - the swap must be whitelisted.
     */
    function removeSwapRouterFromWhitelist(address swapRouter) external override onlyUpgrader {
        if (!whitelistedSwapRouters[swapRouter]) revert VaultErrors.SwapRouterIsNotWhitelisted();

        uint256 length = swapRouters.length;
        for (uint256 i = 0; i < length; i++) {
            if (swapRouters[i] == swapRouter) {
                swapRouters[i] = swapRouters[length - 1];
                swapRouters.pop();
                delete whitelistedSwapRouters[swapRouter];
                emit SwapRouterRemovedFromWhitelist(swapRouter);
                break;
            }
        }
    }

    /**
     * @dev whiteListTarget allows whitelisting the target address that can be called by the vault through multicallByManager
     * function.
     * @param target the address to add to the targets whitelist.
     * requirements
     * - only upgrader can call this function.
     * - the target address must not be already whitelisted.
     */
    function whiteListTarget(address target) external override onlyUpgrader {
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
    function removeTargetFromWhitelist(address target) external override onlyUpgrader {
        if (!whitelistedTargets[target]) revert VaultErrors.TargetIsNotWhitelisted();

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
     * @dev changeSwapThreshold allows changing of swap threshold. Swap threshold is the minimum acceptable ratio of
     * vault's underlying balance before and after the swap through {swap} function.
     * @param newSwapThreshold the new swapThreshold to set.
     * requirements
     * - only upgrader can call this function.
     */
    function changeSwapThreshold(uint256 newSwapThreshold) external override onlyUpgrader {
        // @note we are not adding a limit check on swap threshold optimistically assuming that the upgrader will
        // set a reasonable limit on the swap threshold.
        swapThreshold = newSwapThreshold;
        emit SwapThresholdChanged(newSwapThreshold);
    }

    function addAsset(IERC20 asset, AssetData memory assetData) external override onlyUpgrader {
        _addAsset(asset, assetData);
    }

    function removeAsset(IERC20 asset) external override onlyUpgrader {
        _removeAsset(asset);
    }

    /**
     * @dev getMintAmount returns the amount of vault shares user gets upon depositing the {depositAmount} of usdc.
     * @param depositAmount the amount of usdc to deposit.
     */
    function getMintAmount(uint256 depositAmount) external view override returns (uint256) {
        uint256 _totalSupply = totalSupply();
        if (_totalSupply == 0) return depositAmount * DECIMALS_DIFFERENCE_MULTIPLIER;
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
     * @dev returns underlying vault holding in {usdc}. The vault holding represents passive USDC, wBTC and wETH in the vault
     * along with any PnL from the whitelisted perp products on the Vertex protocol.
     * @return vaultBalance the total holding of the vault in USDC.
     */
    function getUnderlyingBalance() public view override returns (uint256 vaultBalance) {
        uint256 usdcPrice = uint256(getPriceFromOracle(usdc));
        uint256 usdcDecimalsMultiplier = 10 ** IERC20Metadata(address(usdc)).decimals();
        uint256 usdcPriceFeedDecimalsMultiplier = 10 ** assetsData[usdc].priceFeed.decimals();

        uint256[] memory _productIds = productIds;
        uint256[] memory pendingBalances = getPendingBalances();
        int256 signedBalance;
        for (uint256 i = 0; i < _productIds.length; i++) {
            uint32 productId = uint32(_productIds[i]);
            // only compute perps pnl balances.
            if (productId % 2 == 0 && productId != 0) {
                signedBalance += _perpPnLByProductId(productId, usdcDecimalsMultiplier);
            } else {
                IERC20Metadata asset = IERC20Metadata(address(spotIdToAsset[productId]));
                uint256 assetDecimalsMultiplier = 10 ** asset.decimals();
                int256 amountToAdd = _spotBalanceByProductId(productId, assetDecimalsMultiplier)
                    + int256(pendingBalances[assetsData[asset].idx]) + int256(asset.balanceOf(address(this)));

                if (productId != 0) {
                    amountToAdd = getAssetAmountInUsdc(
                        asset,
                        amountToAdd,
                        assetDecimalsMultiplier,
                        usdcPrice,
                        usdcDecimalsMultiplier,
                        usdcPriceFeedDecimalsMultiplier
                    );
                }

                signedBalance += amountToAdd;
            }
        }
        if (signedBalance < 0) revert VaultErrors.VaultIsUnderWater();

        vaultBalance = uint256(signedBalance);

        // We optimistically assume that managerBalance will always be part of passive balance
        // but in the event, it is not there, we add this check to avoid the underflow.
        if (vaultBalance >= managerBalance) vaultBalance -= managerBalance;
    }

    /**
     * @dev returns the asset's (wETH or wBTC) amount in usdc.
     * @param asset the address of the asset.
     * @param usdcPrice the price of usdc (passed as param for caching purpose)
     * @param usdcDecimalsMultiplier the decimals multiplier for usdc (passed as param for caching purpose)
     * @return the asset holding of the vault in usdc.
     */
    function getAssetAmountInUsdc(
        IERC20Metadata asset,
        int256 amount,
        uint256 assetDecimalsMultiplier,
        uint256 usdcPrice,
        uint256 usdcDecimalsMultiplier,
        uint256 usdcPriceFeedDecimalsMultiplier
    )
        public
        view
        returns (int256)
    {
        uint256 amountInUsdc = uint256(amount > 0 ? amount : -amount) * uint256(getPriceFromOracle(asset))
            * usdcDecimalsMultiplier * usdcPriceFeedDecimalsMultiplier / 10 ** assetsData[asset].priceFeed.decimals()
            / assetDecimalsMultiplier / usdcPrice;

        return amount < 0 ? -int256(amountInUsdc) : int256(amountInUsdc);
    }

    /**
     * @dev getPriceFromOracle returns price from the price oracle against the {asset}.
     * @param token the token for which the price oracle is queried.
     * requirements
     * - price must not be older than two days
     */
    function getPriceFromOracle(IERC20 token) public view returns (int256) {
        (, int256 price,, uint256 updatedAt,) = assetsData[token].priceFeed.latestRoundData();
        if (block.timestamp - updatedAt > assetsData[token].heartbeat) revert VaultErrors.OutdatedPrice();
        return price;
    }

    /**
     * @dev getting pending balance from vertex.
     * It checks all the queued transaction and fetched the deposit transactions
     * sent by the vault and calculate pending balance from it.
     * @return pendingBalances the pending balances amounts.
     */
    function getPendingBalances() public view override returns (uint256[] memory pendingBalances) {
        pendingBalances = new uint256[](assets.length);
        (, uint64 txUpTo, uint64 txCount) = endpoint.getSlowModeTx(0);
        for (uint64 i = txUpTo; i < txCount; i++) {
            (IEndpoint.SlowModeTx memory slowMode,,) = endpoint.getSlowModeTx(i);
            if (slowMode.sender != address(this)) continue;

            (uint8 txType, bytes memory payload) = this.decodeTx(slowMode.tx);
            if (txType == uint8(IEndpoint.TransactionType.DepositCollateral)) {
                IEndpoint.DepositCollateral memory depositPayload = abi.decode(payload, (IEndpoint.DepositCollateral));
                IERC20 asset = spotIdToAsset[depositPayload.productId];
                if (asset == IERC20(address(0x0))) continue;
                pendingBalances[assetsData[asset].idx] += uint256(depositPayload.amount);
            }
        }
    }

    function assetsList() external view override returns (IERC20[] memory) {
        return assets;
    }

    /**
     * @dev utility function to slice the transaction data.
     */
    function decodeTx(bytes calldata transaction) public pure returns (uint8, bytes memory) {
        return (uint8(transaction[0]), transaction[1:]);
    }

    function _spotBalanceByProductId(uint32 productId, uint256 assetDecimalsMultiplier) private view returns (int256) {
        return int256(spotEngine.getBalance(productId, contractSubAccount).amount) * int256(assetDecimalsMultiplier)
            / X18_MULTIPLIER;
    }

    function _perpPnLByProductId(uint32 productId, uint256 usdcDecimalsMultiplier) private view returns (int256) {
        return int256(perpEngine.getPositionPnl(productId, contractSubAccount)) * int256(usdcDecimalsMultiplier)
            / X18_MULTIPLIER;
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
     * @return amountAfterFee the {usdc} amount redeemable after
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

    function _addAsset(IERC20 asset, AssetData memory assetData) private {
        if (assetsData[asset].perpId != 0) revert VaultErrors.AssetAlreadyAdded();
        assetData.idx = assets.length;
        assetsData[asset] = assetData;
        spotIdToAsset[assetData.spotId] = asset;
        assets.push(asset);
        emit AssetAdded(asset);
    }

    function _removeAsset(IERC20 asset) private {
        if (assetsData[asset].perpId == 0) revert VaultErrors.AssetNotAdded();
        delete spotIdToAsset[assetsData[asset].spotId];
        delete assetsData[asset];

        uint256 length = assets.length;
        for (uint256 i = 0; i < length; i++) {
            if (assets[i] == asset) {
                assets[i] = assets[length - 1];
                assets.pop();
                break;
            }
        }
        emit AssetRemoved(asset);
    }
}
