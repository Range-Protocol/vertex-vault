// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Test, console2 } from 'forge-std/Test.sol';
import { IERC20 } from '@openzeppelin/contracts/interfaces/IERC20.sol';

import { SkateVertexVault } from '../src/SkateVertexVault.sol';
import { ISkateVertexVault } from '../src/interfaces/ISkateVertexVault.sol';
import { ISpotEngine } from '../src/interfaces/vertex/ISpotEngine.sol';
import { IPerpEngine } from '../src/interfaces/vertex/IPerpEngine.sol';
import { IEndpoint } from '../src/interfaces/vertex/IEndpoint.sol';
import { IUSDC } from './IUSDC.sol';
import { VaultErrors } from '../src/errors/VaultErrors.sol';
import { FullMath } from '../src/libraries/FullMath.sol';
import { ERC1967Proxy } from
    'openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import { AggregatorV3Interface } from '@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol';

contract SkateVertexVaultTest is Test {
    event Minted(address user, uint256 shares, uint256 amount);
    event Burned(address user, uint256 shares, uint256 amount);
    event ProductAdded(uint256 product);
    event ProductRemoved(uint256 product);
    event ManagingFeeSet(uint256 managingFee);
    event AssetAdded(IERC20 asset);
    event AssetRemoved(IERC20 asset);

    error FailedInnerCall();
    error EnforcedPause();

    ISpotEngine spotEngine = ISpotEngine(0xb64d2d606DC23D7a055B770e192631f5c8e1d9f8);
    IPerpEngine perpEngine = IPerpEngine(0x38080ee5fb939d045A9e533dF355e85Ff4f7e13D);
    IEndpoint endpoint = IEndpoint(0x526D7C7ea3677efF28CB5bA457f9d341F297Fd52);
    IUSDC usdc = IUSDC(0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9);
    IERC20 wETH = IERC20(0xdEAddEaDdeadDEadDEADDEAddEADDEAddead1111);
    IERC20 wBTC = IERC20(0xCAbAE6f6Ea1ecaB08Ad02fE02ce9A44F09aebfA2);

    SkateVertexVault vault;
    address manager = 0x38E292E52302351aAdf5Ef51D4d3bb30bD355b25;
    address upgrader = 0xCAbAE6f6Ea1ecaB08Ad02fE02ce9A44F09aebfA2;
    //    address swapRouter = 0xEAd050515E10fDB3540ccD6f8236C46790508A76;

    function setUp() external {
        uint256 fork = vm.createFork(vm.rpcUrl('mantle'));
        vm.selectFork(fork);
        vm.prank(0x588846213A30fd36244e0ae0eBB2374516dA836C);
        usdc.transfer(manager, 100_000 * 10 ** 6);

        address vaultImpl = address(new SkateVertexVault());
        vault = SkateVertexVault(
            address(
                new ERC1967Proxy(
                    vaultImpl,
                    abi.encodeWithSignature(
                        'initialize(address,address,address,address,address,string,string,address)',
                        address(spotEngine),
                        address(perpEngine),
                        address(endpoint),
                        address(usdc),
                        manager,
                        'Vertex Test Vault',
                        'VTX',
                        upgrader
                    )
                )
            )
        );

        vm.startPrank(manager);
    }

    function testDeployment() external {
        ISkateVertexVault.AssetData[] memory assetsDataList = new ISkateVertexVault.AssetData[](3);
        assetsDataList[0] = ISkateVertexVault.AssetData(
            0, 0, 0, AggregatorV3Interface(0x1bB8f2dF000553E5Af2AEd5c42FEd3a73cd5144b), 86_400 + 1800
        );
        assetsDataList[1] = ISkateVertexVault.AssetData(
            1, 93, 4, AggregatorV3Interface(0xFc34806fbD673c21c1AEC26d69AA247F1e69a2C6), 86_400 + 1800
        );
        assetsDataList[2] = ISkateVertexVault.AssetData(
            2, 10_001, 2, AggregatorV3Interface(0x76A495b0bFfb53ef3F0E94ef0763e03cE410835C), 86_400 + 1800
        );
        IERC20[] memory assets = vault.assetsList();
        for (uint256 i = 0; i < assets.length; i++) {
            (uint256 idx, uint256 spotId, uint256 perpId, AggregatorV3Interface priceFeed, uint256 heartbeat) =
                vault.assetsData(assets[i]);
            assertEq(idx, assetsDataList[i].idx);
            assertEq(spotId, assetsDataList[i].spotId);
            assertEq(perpId, assetsDataList[i].perpId);
            assertEq(address(priceFeed), address(assetsDataList[i].priceFeed));
            assertEq(heartbeat, assetsDataList[i].heartbeat);
        }

        assertEq(vault.upgrader(), upgrader);
        assertEq(vault.whitelistedTargets(address(usdc)), true);
        assertEq(vault.targets(0), address(usdc));
        assertEq(vault.whitelistedTargets(address(endpoint)), true);
        assertEq(vault.targets(3), address(endpoint));
        assertEq(vault.whitelistedSwapRouters(address(0xc6f7a7ba5388bFB5774bFAa87D350b7793FD9ef1)), true);
        assertEq(vault.swapRouters(0), address(0xc6f7a7ba5388bFB5774bFAa87D350b7793FD9ef1));
        assertEq(vault.swapThreshold(), 9995);
    }

    function testRemoveAssetByNonUpgrader() external {
        vm.expectRevert(VaultErrors.OnlyUpgraderAllowed.selector);
        vault.removeAsset(wETH);
    }

    function testRemoveAsset() external {
        (uint256 idx, uint256 spotId,,,) = vault.assetsData(wETH);
        assertEq(spotId, 93);
        assertEq(address(vault.assets(idx)), address(wETH));
        assertEq(address(vault.spotIdToAsset(spotId)), address(wETH));

        vm.startPrank(upgrader);
        vm.expectEmit();
        emit AssetRemoved(wETH);
        vault.removeAsset(wETH);
        (, spotId,,,) = vault.assetsData(wETH);

        assertEq(spotId, 0);
        assertNotEq(address(vault.assets(idx)), address(wETH));
        assertNotEq(address(vault.spotIdToAsset(spotId)), address(wETH));

        vm.expectRevert(VaultErrors.AssetNotAdded.selector);
        vault.removeAsset(wETH);
    }

    function testAddAssetByNonUpgrader() external {
        vm.expectRevert(VaultErrors.OnlyUpgraderAllowed.selector);
        vault.addAsset(
            wETH,
            ISkateVertexVault.AssetData(
                1, 3, 4, AggregatorV3Interface(0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612), 86_400 + 1800
            )
        );
    }

    function testAddAsset() external {
        vm.stopPrank();
        vm.startPrank(upgrader);
        vault.removeAsset(wETH);

        (uint256 idx, uint256 spotId,,,) = vault.assetsData(wETH);
        assertEq(spotId, 0);
        assertNotEq(address(vault.assets(idx)), address(wETH));
        assertNotEq(address(vault.spotIdToAsset(spotId)), address(wETH));

        vm.expectEmit();
        emit AssetAdded(wETH);
        vault.addAsset(
            wETH,
            ISkateVertexVault.AssetData(
                1, 3, 4, AggregatorV3Interface(0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612), 86_400 + 1800
            )
        );
        (idx, spotId,,,) = vault.assetsData(wETH);
        assertEq(spotId, 3);
        assertEq(address(vault.assets(idx)), address(wETH));
        assertEq(address(vault.spotIdToAsset(spotId)), address(wETH));

        vm.expectRevert(VaultErrors.AssetAlreadyAdded.selector);
        vault.addAsset(
            wETH,
            ISkateVertexVault.AssetData(
                1, 3, 4, AggregatorV3Interface(0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612), 86_400 + 1800
            )
        );
    }

    //    function testSwapWithNonWhitelistedTarget() external {
    //        bytes memory callData = vm.envBytes('calldata');
    //        vm.expectRevert(VaultErrors.SwapRouterIsNotWhitelisted.selector);
    //        vault.swap(address(0x123), callData, IERC20(address(0x123)), 0);
    //    }
    //
    //    function testSwap() external {
    //        bytes memory callData = vm.envBytes('calldata');
    //        vault.swap(swapRouter, callData, IERC20(address(usdc)), 2000e6);
    //    }

    function testUnderlyingBalance() external {
        //        deal(address(wETH), manager, 100_000e18);
        //        wETH.transfer(address(vault), 10e18);
        //
        //        deal(address(wBTC), manager, 100_000e8);
        //        wBTC.transfer(address(vault), 10e8);
        console2.log(vault.getPendingBalances()[0]);
        console2.log(vault.getPendingBalances()[1]);
        console2.log(vault.getPendingBalances()[2]);
        console2.log(vault.getUnderlyingBalance());
    }

    function testChangeUpgraderByNonUpgrader() external {
        vm.expectRevert(VaultErrors.OnlyUpgraderAllowed.selector);
        vm.stopPrank();
        vm.prank(address(0x1));
        vault.changeUpgrader(address(0x1));
    }

    function testChangeUpgraderAddress() external {
        assertEq(vault.upgrader(), upgrader);
        vm.startPrank(upgrader);
        vault.changeUpgrader(address(0x1));
        assertEq(vault.upgrader(), address(0x1));
    }

    function testWhitelistSwapRouterByNonUpgrader() external {
        vm.expectRevert(VaultErrors.OnlyUpgraderAllowed.selector);
        vm.stopPrank();
        vm.prank(address(0x1));
        vault.whiteListSwapRouter(address(0x123));
    }

    function testWhitelistSwapRouter() external {
        assertEq(vault.whitelistedSwapRouters(address(0x123)), false);
        vm.startPrank(upgrader);
        vault.whiteListSwapRouter(address(0x123));
        assertEq(vault.whitelistedSwapRouters(address(0x123)), true);
    }

    function testWhitelistTargetByNonUpgrader() external {
        vm.expectRevert(VaultErrors.OnlyUpgraderAllowed.selector);
        vm.stopPrank();
        vm.prank(address(0x1));
        vault.whiteListTarget(address(0x123));
    }

    function testWhitelistTarget() external {
        assertEq(vault.whitelistedTargets(address(0x123)), false);
        vm.startPrank(upgrader);
        vault.whiteListTarget(address(0x123));
        assertEq(vault.whitelistedTargets(address(0x123)), true);
    }

    function testRemoveTargetFromWhitelistByNonUpgrader() external {
        vm.expectRevert(VaultErrors.OnlyUpgraderAllowed.selector);
        vm.stopPrank();
        vm.prank(address(0x1));
        vault.removeTargetFromWhitelist(address(0x123));
    }

    function testRemoveTargetFromWhitelist() external {
        assertEq(vault.whitelistedTargets(address(0x123)), false);
        vm.startPrank(upgrader);
        vault.whiteListTarget(address(0x123));
        assertEq(vault.whitelistedTargets(address(0x123)), true);

        vault.removeTargetFromWhitelist(address(0x123));
        assertEq(vault.whitelistedTargets(address(0x123)), false);
    }

    function testChangeSwapThresholdByNonUpgrader() external {
        vm.expectRevert(VaultErrors.OnlyUpgraderAllowed.selector);
        vm.stopPrank();
        vm.prank(address(0x1));
        vault.changeSwapThreshold(9900);
    }

    function testChangeSwapThreshold() external {
        assertEq(vault.swapThreshold(), 9995);
        vm.startPrank(upgrader);
        vault.changeSwapThreshold(9900);
        assertEq(vault.swapThreshold(), 9900);
    }

    function testMintWithZeroAmount() external {
        vm.expectRevert(VaultErrors.ZeroDepositAmount.selector);
        vault.mint(0, 0);
    }

    function testMintWithoutApprove() external {
        uint256 amount = 1000 * 10 ** 6;
        vm.expectRevert(bytes('ERC20: transfer amount exceeds allowance'));
        vault.mint(amount, 0);
    }

    function testMintWhenPaused() external {
        vault.pause();
        uint256 amount = 1000 * 10 ** 6;
        vm.expectRevert(EnforcedPause.selector);
        vault.mint(amount, 0);
    }

    function testMint() external {
        uint256 amount = 1e6;
        usdc.approve(address(vault), amount);

        uint256 vaultBalanceBefore = vault.getUnderlyingBalance();
        uint256 minShares = vault.getMintAmount(amount);
        //        console2.log(minShares);
        vm.expectEmit();
        emit Minted(manager, minShares, amount);
        vault.mint(amount, minShares);
        console2.log(vault.balanceOf(manager));
        assertEq(vault.getUnderlyingBalance(), vaultBalanceBefore + amount);
        console2.log(vault.getUnderlyingBalanceByShares(vault.balanceOf(manager)));
    }

    function testBurnZeroAmount() external {
        vm.expectRevert(VaultErrors.ZeroBurnAmount.selector);
        vault.burn(0, 0);
    }

    function testBurnWithoutOwningShares() external {
        vm.stopPrank();
        vm.prank(address(0x1));
        vm.expectRevert();
        vault.burn(1000, 0);
        vm.startPrank(manager);
    }

    function testBurnWithMoreThanExpectedAmount() external {
        uint256 amount = 1e6;
        usdc.approve(address(vault), amount);
        vault.mint(amount, 0);
        uint256 vaultShares = vault.balanceOf(manager);
        uint256 expectedAmount = vault.getUnderlyingBalanceByShares(vaultShares);

        vm.expectRevert(VaultErrors.AmountIsLessThanMinAmount.selector);
        vault.burn(vaultShares, expectedAmount + 100);
    }

    function testBurnWhenPaused() external {
        uint256 amount = 1e6;
        usdc.approve(address(vault), amount);
        vault.mint(amount, 0);
        vault.pause();
        uint256 burnAmount = vault.balanceOf(manager);
        vm.expectRevert(EnforcedPause.selector);
        vault.burn(burnAmount, 0);
    }

    function testBurn() external {
        //        usdc.transfer(address(vault), 100e6);
        uint256 amount = 10e6;
        usdc.approve(address(vault), amount);
        vault.mint(amount, 0);

        uint256 vaultShares = vault.balanceOf(manager);
        uint256 expectedAmount = vault.getUnderlyingBalanceByShares(vaultShares);
        uint256 expectedManagerBalance = vault.managerBalance() + (expectedAmount * 10_000 / 9900) - expectedAmount;

        vm.expectEmit();
        emit Burned(manager, vaultShares, expectedAmount);
        vault.burn(vaultShares, expectedAmount);

        assertEq(vault.managerBalance(), expectedManagerBalance);
        uint256 managerAccountBalanceBefore = usdc.balanceOf(manager);
        vault.collectManagerFee();
        assertEq(vault.managerBalance(), 0);
        assertEq(usdc.balanceOf(manager), managerAccountBalanceBefore + expectedManagerBalance);
    }

    //    function testBurnWithZeroRedeemableAmount() external {
    //        vm.expectRevert(VaultErrors.ZeroAmountRedeemed.selector);
    //        vault.burn(1, 0);
    //    }
    //
    function testSetManagingFeeByNonManager() external {
        vm.stopPrank();
        vm.prank(address(0x1));
        vm.expectRevert(bytes('Ownable: caller is not the manager'));
        vault.setManagingFee(2000);
        vm.startPrank(manager);
    }

    function testSetManagerFee() external {
        assertEq(vault.managingFee(), 100);
        vault.setManagingFee(200);
        assertEq(vault.managingFee(), 200);
    }

    function testSetInvalidManagerFee() external {
        uint256 feeToSet = vault.MAX_MANAGING_FEE() + 1;
        vm.expectRevert(VaultErrors.InvalidManagingFee.selector);
        vault.setManagingFee(feeToSet);
    }

    function testAddProductByNonManager() external {
        vm.stopPrank();
        vm.prank(address(0x1));
        vm.expectRevert(bytes('Ownable: caller is not the manager'));
        vault.addProduct(20);
        vm.startPrank(manager);
    }

    function testAddProduct() external {
        uint256 productToWhitelist = 20;
        assertEq(vault.isWhiteListedProduct(productToWhitelist), false);
        vault.addProduct(productToWhitelist);
        assertEq(vault.isWhiteListedProduct(productToWhitelist), true);
    }

    function testAddSameProductTwice() external {
        uint256 productToWhitelist = 20;
        vault.addProduct(productToWhitelist);
        vm.expectRevert(VaultErrors.ProductAlreadyWhitelisted.selector);
        vault.addProduct(productToWhitelist);
    }

    function testRemoveProductByNonManager() external {
        uint256 productToUnWhitelist = 20;
        vault.addProduct(productToUnWhitelist);
        assertEq(vault.isWhiteListedProduct(productToUnWhitelist), true);
        vm.stopPrank();
        vm.expectRevert(VaultErrors.OnlyUpgraderAllowed.selector);
        vault.removeProduct(productToUnWhitelist);
        vm.startPrank(manager);
    }

    function testRemoveProduct() external {
        uint256 productToUnWhitelist = 20;
        vault.addProduct(productToUnWhitelist);
        vm.stopPrank();

        assertEq(vault.isWhiteListedProduct(productToUnWhitelist), true);
        vm.prank(vault.upgrader());
        vault.removeProduct(productToUnWhitelist);
        assertEq(vault.isWhiteListedProduct(productToUnWhitelist), false);
        vm.startPrank(manager);
    }

    function testRemoveAlreadyRemovedProduct() external {
        uint256 productToUnWhitelist = 20;
        vault.addProduct(productToUnWhitelist);
        vm.stopPrank();

        vm.prank(vault.upgrader());
        vault.removeProduct(productToUnWhitelist);

        vm.prank(vault.upgrader());
        vm.expectRevert(VaultErrors.ProductIsNotWhitelisted.selector);
        vault.removeProduct(productToUnWhitelist);
        vm.startPrank(manager);
    }

    //    function testUnderlyingBalanceWithInvalidShareAmount() external {
    //        uint256 shareToQueryUnderlyingBalanceFor = vault.totalSupply() + 1;
    //        vm.expectRevert(VaultErrors.InvalidShareAmount.selector);
    //        vault.getUnderlyingBalanceByShares(shareToQueryUnderlyingBalanceFor);
    //    }

    function testMulticallWithNonManager() external {
        vm.stopPrank();
        address[] memory targets = new address[](1);
        bytes[] memory data = new bytes[](1);
        targets[0] = address(endpoint);
        data[0] = '0x';
        vm.prank(address(0x1));
        vm.expectRevert(bytes('Ownable: caller is not the manager'));
        vault.multicallByManager(targets, data);
        vm.startPrank(manager);
    }

    function testMulticallWithZeroTargets() external {
        address[] memory targets = new address[](0);
        bytes[] memory data = new bytes[](0);
        vm.expectRevert(VaultErrors.InvalidLength.selector);
        vault.multicallByManager(targets, data);

        targets = new address[](1);
        data = new bytes[](0);
        vm.expectRevert(VaultErrors.InvalidLength.selector);
        vault.multicallByManager(targets, data);
    }

    function testMulticallWithDepositTokenAndNonApproveFunction() external {
        address[] memory targets = new address[](1);
        bytes[] memory data = new bytes[](1);
        targets[0] = address(usdc);
        data[0] = abi.encode(bytes4(uint32(0)));
        vm.expectRevert(VaultErrors.InvalidMulticall.selector);
        vault.multicallByManager(targets, data);
    }

    function testMulticallWithDepositTokenAndApproveFunctionWithNonEndpointAddress() external {
        address[] memory targets = new address[](1);
        bytes[] memory data = new bytes[](1);
        targets[0] = address(usdc);
        data[0] = abi.encodeWithSelector(usdc.approve.selector, address(0x1), 123);
        vm.expectRevert(VaultErrors.InvalidMulticall.selector);
        vault.multicallByManager(targets, data);
    }

    function testMulticallWithDepositTokenAndApproveFunction() external {
        address[] memory targets = new address[](1);
        bytes[] memory data = new bytes[](1);
        targets[0] = address(usdc);
        data[0] = abi.encodeWithSelector(usdc.approve.selector, address(endpoint), 123);
        vault.multicallByManager(targets, data);
    }

    //    function testMulticallWithEndpoint() external {
    //        address[] memory targets = new address[](2);
    //        bytes[] memory data = new bytes[](2);
    //
    //        targets[0] = address(usdc);
    //        data[0] = abi.encodeWithSelector(usdc.approve.selector, address(endpoint), 1_000_000);
    //        targets[1] = address(endpoint);
    //        data[1] = vm.envBytes('calldata');
    //        vault.multicallByManager(targets, data);
    //    }

    function testMulticallWithNonWhitelistedAddress() external {
        address[] memory targets = new address[](1);
        bytes[] memory data = new bytes[](1);
        targets[0] = address(0x1);
        data[0] = abi.encode(usdc.approve.selector);
        vm.expectRevert(VaultErrors.TargetIsNotWhitelisted.selector);
        vault.multicallByManager(targets, data);
    }

    function testMulticallWithwEthAndwBTC() external {
        address[] memory targets = new address[](1);
        bytes[] memory data = new bytes[](1);
        targets[0] = address(vault.assets(1));
        data[0] = abi.encodeWithSelector(usdc.approve.selector, address(0x0), 0);
        vm.expectRevert(VaultErrors.InvalidMulticall.selector);
        vault.multicallByManager(targets, data);

        targets[0] = address(vault.assets(2));
        data[0] = abi.encodeWithSelector(usdc.approve.selector, address(0x0), 0);
        vm.expectRevert(VaultErrors.InvalidMulticall.selector);
        vault.multicallByManager(targets, data);
    }

    //    function testActual() external {
    ////        address[] memory targets = new address[](1);
    ////        bytes[] memory data = new bytes[](1);
    ////        targets[0] = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    ////        data[0] = abi.encodeWithSignature(
    ////            "approve(address,uint256)",
    ////            0xbbEE07B3e8121227AfCFe1E2B82772246226128e,
    ////            1000000
    ////        );
    //////        address[] memory targets = new address[](1);
    //////        bytes[] memory data = new bytes[](1);
    //////        targets[0] = address(usdc);
    //////        data[0] = abi.encodePacked(bytes4(usdc.approve.selector), abi.encode(address(endpoint), uint256(1000000)));
    //////        console2.logBytes(abi.encodePacked(bytes4(usdc.approve.selector), abi.encode(address(endpoint), uint256(1000000))));
    ////        vault.multicallByManager(targets, data);
    ////        address(vault).call(vm.envBytes("data"));
    //    }
}
