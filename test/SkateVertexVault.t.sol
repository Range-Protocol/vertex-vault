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

contract SkateProtocolVertexVaultTest is Test {
    event Minted(address user, uint256 shares, uint256 amount);
    event Burned(address user, uint256 shares, uint256 amount);
    event ProductAdded(uint256 product);
    event ProductRemoved(uint256 product);
    event ManagingFeeSet(uint256 managingFee);
    event AssetAdded(IERC20 asset);
    event AssetRemoved(IERC20 asset);
    event Claimed(address, uint256);
    event MerkleRootsSet(bytes32, bytes32);

    error FailedInnerCall();
    error EnforcedPause();

    ISpotEngine spotEngine = ISpotEngine(0x32d91Af2B17054D575A7bF1ACfa7615f41CCEfaB);
    IPerpEngine perpEngine = IPerpEngine(0xb74C78cca0FADAFBeE52B2f48A67eE8c834b5fd1);
    IEndpoint endpoint = IEndpoint(0xbbEE07B3e8121227AfCFe1E2B82772246226128e);
    IUSDC usdc = IUSDC(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);
    IERC20 wETH = IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    IERC20 wBTC = IERC20(0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f);

    SkateVertexVault vault;
    address manager = 0x38E292E52302351aAdf5Ef51D4d3bb30bD355b25;
    address upgrader = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
    address arb = 0x912CE59144191C1204E64559FE8253a0e49E6548;
    address vrtx = 0x95146881b86B3ee99e63705eC87AfE29Fcc044D9;
    //    address swapRouter = 0xEAd050515E10fDB3540ccD6f8236C46790508A76;

    function setUp() external {
        uint256 fork = vm.createFork(vm.rpcUrl('arbitrum'));
        vm.selectFork(fork);
        vm.prank(0xB38e8c17e38363aF6EbdCb3dAE12e0243582891D);
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
                        'Skate Vertex Liquidity Vault (Majors)',
                        'SK-LP',
                        upgrader
                    )
                )
            )
        );

        vm.startPrank(manager);
    }

    function testRewardClaiming() external {
        vault.reinit();
        uint256 amount = 100_000e18;
        deal(arb, address(vault), amount);
        deal(vrtx, address(vault), amount);

        bytes32 arbMerkleRoot = 0x51e4dba10a1b55d0ff22c1b5869dbf0c004a5026e0a1ba6e990d208070260072;
//        bytes32 vrtxMerkleRoot = bytes32(0x0);

//        vm.expectEmit();
//        emit MerkleRootsSet(arbMerkleRoot, vrtxMerkleRoot);
        vault.setMerkleRoots(arbMerkleRoot, bytes32(0x0));

//        assertEq(IERC20(arb).balanceOf(0xBBE307DB73D8fD981A7dAB929E2a41225CF0658A, 0);
//        assertEq(IERC20(vrtx).balanceOf(address(this)), 0);
        console2.log(IERC20(arb).balanceOf(0xBBE307DB73D8fD981A7dAB929E2a41225CF0658A));

        bytes32[] memory proofArb = new bytes32[](13);
        proofArb[0] = 0xa80e5306de195015ac74e8bd640c6ca10a66edb4deb1616009388572f9a16106;
        proofArb[1] = 0xe0c85257ff3553676c715ea50d3a50152a4f75e9f6034b3d3965fa10be2863cb;
        proofArb[2] = 0xfbee63a2604518207141d69ba094f4a5d648d5e1a97f03a1882f9233d7e6aded;
        proofArb[3] = 0x3cf54bbf1df4d8fb22eb1f7ccdae43f62f703138204b818eb4f5eaad6f03f7ae;
        proofArb[4] = 0x7084eea43bdcad591de7c3a2d19e1b2b0b989392fe13e5bae07bc3452b1b35de;
        proofArb[5] = 0x9396a267f9c63772912801a59f26993f6c88877c4324643e754b0e2592abd4c3;
        proofArb[6] = 0x3d3d5be34f3227086f893f829b09635b33ff7046e045274c1110914133eae869;
        proofArb[7] = 0x40d03556620d33bd7925bebf7cf25a6d59af3f3bcd31c6b0371a5c9b70895cc1;
        proofArb[8] = 0xe0141c5b95cf60987ee3117b5ea8299d0cd816d10e5f52d0a3da0d419517e598;
        proofArb[9] = 0x2dc0f674d72eea6d7c0554c301a838649e95a9797226de8a55bf9d44ae0d0e25;
        proofArb[10] = 0xcefabd2e08084a8df263ed0d5dc79eebb710fb7ae76255c52a93100547c6129f;
        proofArb[11] = 0x612b2451a888ba6eb1da89eff51adb7e1941d1252f9bbda7beb6a10f78b2303f;
        proofArb[12] = 0xdbfc4d02c05c9188d3ca0a95a7a116657ab84dc52a43d4dad89d6a184b21ab05;



//        bytes32[] memory proofVrtx = new bytes32[](1);
//        proofVrtx[0] = 0xd4bd6a9c6f842f3e33f034135838caa1c3c31b5484f717870173dee8820312e0;

//        assertEq(vault.arbClaimedAmounts(address(this)), 0);
//        vm.expectEmit();
//        emit Claimed(0xBBE307DB73D8fD981A7dAB929E2a41225CF0658A, 1575545659216540416);
        vault.claim(arb, 0xBBE307DB73D8fD981A7dAB929E2a41225CF0658A, 1575543345388768512, proofArb);
//        assertEq(vault.arbClaimedAmounts(address(this)), amount);
        console2.log(IERC20(arb).balanceOf(0xBBE307DB73D8fD981A7dAB929E2a41225CF0658A));

//        assertEq(vault.vrtxClaimedAmounts(address(this)), 0);
//        vm.expectEmit();
//        emit Claimed(address(this), amount);
//        vault.claim(vrtx, address(this), amount, proofVrtx);
//        assertEq(vault.vrtxClaimedAmounts(address(this)), amount);

//        assertEq(IERC20(arb).balanceOf(address(this)), amount);
//        assertEq(IERC20(vrtx).balanceOf(address(this)), amount);
//
//        // repeated calls should not transfer additional reward
//        vault.claim(arb, address(this), amount, proofArb);
////        vault.claim(vrtx, address(this), amount, proofVrtx);
//
//        assertEq(IERC20(arb).balanceOf(address(this)), amount);
//        assertEq(IERC20(vrtx).balanceOf(address(this)), amount);
    }

//    function testDeployment() external {
//        ISkateVertexVault.AssetData[] memory assetsDataList = new ISkateVertexVault.AssetData[](3);
//        assetsDataList[0] = ISkateVertexVault.AssetData(
//            0, 0, 0, AggregatorV3Interface(0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3), 86_400 + 1800
//        );
//        assetsDataList[1] = ISkateVertexVault.AssetData(
//            1, 3, 4, AggregatorV3Interface(0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612), 86_400 + 1800
//        );
//        assetsDataList[2] = ISkateVertexVault.AssetData(
//            2, 1, 2, AggregatorV3Interface(0xd0C7101eACbB49F3deCcCc166d238410D6D46d57), 86_400 + 1800
//        );
//        IERC20[] memory assets = vault.assetsList();
//        for (uint256 i = 0; i < assets.length; i++) {
//            (uint256 idx, uint256 spotId, uint256 perpId, AggregatorV3Interface priceFeed, uint256 heartbeat) =
//                vault.assetsData(assets[i]);
//            assertEq(idx, assetsDataList[i].idx);
//            assertEq(spotId, assetsDataList[i].spotId);
//            assertEq(perpId, assetsDataList[i].perpId);
//            assertEq(address(priceFeed), address(assetsDataList[i].priceFeed));
//            assertEq(heartbeat, assetsDataList[i].heartbeat);
//        }
//
//        assertEq(vault.upgrader(), upgrader);
//        assertEq(vault.whitelistedTargets(address(usdc)), true);
//        assertEq(vault.targets(0), address(usdc));
//        assertEq(vault.whitelistedTargets(address(endpoint)), true);
//        assertEq(vault.targets(3), address(endpoint));
//        assertEq(vault.whitelistedSwapRouters(address(0xEAd050515E10fDB3540ccD6f8236C46790508A76)), true);
//        assertEq(vault.swapRouters(0), address(0xEAd050515E10fDB3540ccD6f8236C46790508A76));
//        assertEq(vault.swapThreshold(), 9995);
//    }
//
//    function testRemoveAssetByNonUpgrader() external {
//        vm.expectRevert(VaultErrors.OnlyUpgraderAllowed.selector);
//        vault.removeAsset(wETH);
//    }
//
//    function testRemoveAsset() external {
//        (uint256 idx, uint256 spotId,,,) = vault.assetsData(wETH);
//        assertEq(spotId, 3);
//        assertEq(address(vault.assets(idx)), address(wETH));
//        assertEq(address(vault.spotIdToAsset(spotId)), address(wETH));
//
//        vm.startPrank(upgrader);
//        vm.expectEmit();
//        emit AssetRemoved(wETH);
//        vault.removeAsset(wETH);
//        (, spotId,,,) = vault.assetsData(wETH);
//
//        assertEq(spotId, 0);
//        assertNotEq(address(vault.assets(idx)), address(wETH));
//        assertNotEq(address(vault.spotIdToAsset(spotId)), address(wETH));
//
//        vm.expectRevert(VaultErrors.AssetNotAdded.selector);
//        vault.removeAsset(wETH);
//    }
//
//    function testAddAssetByNonUpgrader() external {
//        vm.expectRevert(VaultErrors.OnlyUpgraderAllowed.selector);
//        vault.addAsset(
//            wETH,
//            ISkateVertexVault.AssetData(
//                1, 3, 4, AggregatorV3Interface(0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612), 86_400 + 1800
//            )
//        );
//    }
//
//    function testAddAsset() external {
//        vm.stopPrank();
//        vm.startPrank(upgrader);
//        vault.removeAsset(wETH);
//
//        (uint256 idx, uint256 spotId,,,) = vault.assetsData(wETH);
//        assertEq(spotId, 0);
//        assertNotEq(address(vault.assets(idx)), address(wETH));
//        assertNotEq(address(vault.spotIdToAsset(spotId)), address(wETH));
//
//        vm.expectEmit();
//        emit AssetAdded(wETH);
//        vault.addAsset(
//            wETH,
//            ISkateVertexVault.AssetData(
//                1, 3, 4, AggregatorV3Interface(0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612), 86_400 + 1800
//            )
//        );
//        (idx, spotId,,,) = vault.assetsData(wETH);
//        assertEq(spotId, 3);
//        assertEq(address(vault.assets(idx)), address(wETH));
//        assertEq(address(vault.spotIdToAsset(spotId)), address(wETH));
//
//        vm.expectRevert(VaultErrors.AssetAlreadyAdded.selector);
//        vault.addAsset(
//            wETH,
//            ISkateVertexVault.AssetData(
//                1, 3, 4, AggregatorV3Interface(0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612), 86_400 + 1800
//            )
//        );
//    }
//
//    //    function testSwapWithNonWhitelistedTarget() external {
//    //        bytes memory callData = vm.envBytes('calldata');
//    //        vm.expectRevert(VaultErrors.SwapRouterIsNotWhitelisted.selector);
//    //        vault.swap(address(0x123), callData, IERC20(address(0x123)), 0);
//    //    }
//    //
//    //    function testSwap() external {
//    //        bytes memory callData = vm.envBytes('calldata');
//    //        vault.swap(swapRouter, callData, IERC20(address(usdc)), 2000e6);
//    //    }
//
//    function testUnderlyingBalance() external {
//        //        deal(address(wETH), manager, 100_000e18);
//        //        wETH.transfer(address(vault), 10e18);
//        //
//        //        deal(address(wBTC), manager, 100_000e8);
//        //        wBTC.transfer(address(vault), 10e8);
//        console2.log(vault.getPendingBalances()[0]);
//        console2.log(vault.getPendingBalances()[1]);
//        console2.log(vault.getPendingBalances()[2]);
//        console2.log(vault.getUnderlyingBalance());
//    }
//
//    function testChangeUpgraderByNonUpgrader() external {
//        vm.expectRevert(VaultErrors.OnlyUpgraderAllowed.selector);
//        vm.stopPrank();
//        vm.prank(address(0x1));
//        vault.changeUpgrader(address(0x1));
//    }
//
//    function testChangeUpgraderAddress() external {
//        assertEq(vault.upgrader(), upgrader);
//        vm.startPrank(upgrader);
//        vault.changeUpgrader(address(0x1));
//        assertEq(vault.upgrader(), address(0x1));
//    }
//
//    function testWhitelistSwapRouterByNonUpgrader() external {
//        vm.expectRevert(VaultErrors.OnlyUpgraderAllowed.selector);
//        vm.stopPrank();
//        vm.prank(address(0x1));
//        vault.whiteListSwapRouter(address(0x123));
//    }
//
//    function testWhitelistSwapRouter() external {
//        assertEq(vault.whitelistedSwapRouters(address(0x123)), false);
//        vm.startPrank(upgrader);
//        vault.whiteListSwapRouter(address(0x123));
//        assertEq(vault.whitelistedSwapRouters(address(0x123)), true);
//    }
//
//    function testWhitelistTargetByNonUpgrader() external {
//        vm.expectRevert(VaultErrors.OnlyUpgraderAllowed.selector);
//        vm.stopPrank();
//        vm.prank(address(0x1));
//        vault.whiteListTarget(address(0x123));
//    }
//
//    function testWhitelistTarget() external {
//        assertEq(vault.whitelistedTargets(address(0x123)), false);
//        vm.startPrank(upgrader);
//        vault.whiteListTarget(address(0x123));
//        assertEq(vault.whitelistedTargets(address(0x123)), true);
//    }
//
//    function testRemoveTargetFromWhitelistByNonUpgrader() external {
//        vm.expectRevert(VaultErrors.OnlyUpgraderAllowed.selector);
//        vm.stopPrank();
//        vm.prank(address(0x1));
//        vault.removeTargetFromWhitelist(address(0x123));
//    }
//
//    function testRemoveTargetFromWhitelist() external {
//        assertEq(vault.whitelistedTargets(address(0x123)), false);
//        vm.startPrank(upgrader);
//        vault.whiteListTarget(address(0x123));
//        assertEq(vault.whitelistedTargets(address(0x123)), true);
//
//        vault.removeTargetFromWhitelist(address(0x123));
//        assertEq(vault.whitelistedTargets(address(0x123)), false);
//    }
//
//    function testChangeSwapThresholdByNonUpgrader() external {
//        vm.expectRevert(VaultErrors.OnlyUpgraderAllowed.selector);
//        vm.stopPrank();
//        vm.prank(address(0x1));
//        vault.changeSwapThreshold(9900);
//    }
//
//    function testChangeSwapThreshold() external {
//        assertEq(vault.swapThreshold(), 9995);
//        vm.startPrank(upgrader);
//        vault.changeSwapThreshold(9900);
//        assertEq(vault.swapThreshold(), 9900);
//    }
//
//    function testMintWithZeroAmount() external {
//        vm.expectRevert(VaultErrors.ZeroDepositAmount.selector);
//        vault.mint(0, 0);
//    }
//
//    function testMintWithoutApprove() external {
//        uint256 amount = 1000 * 10 ** 6;
//        vm.expectRevert(bytes('ERC20: transfer amount exceeds allowance'));
//        vault.mint(amount, 0);
//    }
//
//    function testMintWhenPaused() external {
//        vault.pause();
//        uint256 amount = 1000 * 10 ** 6;
//        vm.expectRevert(EnforcedPause.selector);
//        vault.mint(amount, 0);
//    }
//
//    function testMint() external {
//        uint256 amount = 1e6;
//        usdc.approve(address(vault), amount);
//
//        uint256 vaultBalanceBefore = vault.getUnderlyingBalance();
//        uint256 minShares = vault.getMintAmount(amount);
//        //        console2.log(minShares);
//        vm.expectEmit();
//        emit Minted(manager, minShares, amount);
//        vault.mint(amount, minShares);
//        console2.log(vault.balanceOf(manager));
//        assertEq(vault.getUnderlyingBalance(), vaultBalanceBefore + amount);
//        console2.log(vault.getUnderlyingBalanceByShares(vault.balanceOf(manager)));
//    }
//
//    function testBurnZeroAmount() external {
//        vm.expectRevert(VaultErrors.ZeroBurnAmount.selector);
//        vault.burn(0, 0);
//    }
//
//    function testBurnWithoutOwningShares() external {
//        vm.stopPrank();
//        vm.prank(address(0x1));
//        vm.expectRevert();
//        vault.burn(1000, 0);
//        vm.startPrank(manager);
//    }
//
//    function testBurnWithMoreThanExpectedAmount() external {
//        uint256 amount = 1e6;
//        usdc.approve(address(vault), amount);
//        vault.mint(amount, 0);
//        uint256 vaultShares = vault.balanceOf(manager);
//        uint256 expectedAmount = vault.getUnderlyingBalanceByShares(vaultShares);
//
//        vm.expectRevert(VaultErrors.AmountIsLessThanMinAmount.selector);
//        vault.burn(vaultShares, expectedAmount + 100);
//    }
//
//    function testBurnWhenPaused() external {
//        uint256 amount = 1e6;
//        usdc.approve(address(vault), amount);
//        vault.mint(amount, 0);
//        vault.pause();
//        uint256 burnAmount = vault.balanceOf(manager);
//        vm.expectRevert(EnforcedPause.selector);
//        vault.burn(burnAmount, 0);
//    }
//
//    function testBurn() external {
//        //        usdc.transfer(address(vault), 100e6);
//        uint256 amount = 10e6;
//        usdc.approve(address(vault), amount);
//        vault.mint(amount, 0);
//
//        uint256 vaultShares = vault.balanceOf(manager);
//        uint256 expectedAmount = vault.getUnderlyingBalanceByShares(vaultShares);
//        uint256 expectedManagerBalance = vault.managerBalance() + (expectedAmount * 10_000 / 9900) - expectedAmount;
//
//        vm.expectEmit();
//        emit Burned(manager, vaultShares, expectedAmount);
//        vault.burn(vaultShares, expectedAmount);
//
//        assertEq(vault.managerBalance(), expectedManagerBalance);
//        uint256 managerAccountBalanceBefore = usdc.balanceOf(manager);
//        vault.collectManagerFee();
//        assertEq(vault.managerBalance(), 0);
//        assertEq(usdc.balanceOf(manager), managerAccountBalanceBefore + expectedManagerBalance);
//    }
//
//    //    function testBurnWithZeroRedeemableAmount() external {
//    //        vm.expectRevert(VaultErrors.ZeroAmountRedeemed.selector);
//    //        vault.burn(1, 0);
//    //    }
//    //
//    function testSetManagingFeeByNonManager() external {
//        vm.stopPrank();
//        vm.prank(address(0x1));
//        vm.expectRevert(bytes('Ownable: caller is not the manager'));
//        vault.setManagingFee(2000);
//        vm.startPrank(manager);
//    }
//
//    function testSetManagerFee() external {
//        assertEq(vault.managingFee(), 100);
//        vault.setManagingFee(200);
//        assertEq(vault.managingFee(), 200);
//    }
//
//    function testSetInvalidManagerFee() external {
//        uint256 feeToSet = vault.MAX_MANAGING_FEE() + 1;
//        vm.expectRevert(VaultErrors.InvalidManagingFee.selector);
//        vault.setManagingFee(feeToSet);
//    }
//
//    function testAddProductByNonManager() external {
//        vm.stopPrank();
//        vm.prank(address(0x1));
//        vm.expectRevert(bytes('Ownable: caller is not the manager'));
//        vault.addProduct(20);
//        vm.startPrank(manager);
//    }
//
//    function testAddProduct() external {
//        uint256 productToWhitelist = 20;
//        assertEq(vault.isWhiteListedProduct(productToWhitelist), false);
//        vault.addProduct(productToWhitelist);
//        assertEq(vault.isWhiteListedProduct(productToWhitelist), true);
//    }
//
//    function testAddSameProductTwice() external {
//        uint256 productToWhitelist = 20;
//        vault.addProduct(productToWhitelist);
//        vm.expectRevert(VaultErrors.ProductAlreadyWhitelisted.selector);
//        vault.addProduct(productToWhitelist);
//    }
//
//    function testRemoveProductByNonManager() external {
//        uint256 productToUnWhitelist = 20;
//        vault.addProduct(productToUnWhitelist);
//        assertEq(vault.isWhiteListedProduct(productToUnWhitelist), true);
//        vm.stopPrank();
//        vm.expectRevert(VaultErrors.OnlyUpgraderAllowed.selector);
//        vault.removeProduct(productToUnWhitelist);
//        vm.startPrank(manager);
//    }
//
//    function testRemoveProduct() external {
//        uint256 productToUnWhitelist = 20;
//        vault.addProduct(productToUnWhitelist);
//        vm.stopPrank();
//
//        assertEq(vault.isWhiteListedProduct(productToUnWhitelist), true);
//        vm.prank(vault.upgrader());
//        vault.removeProduct(productToUnWhitelist);
//        assertEq(vault.isWhiteListedProduct(productToUnWhitelist), false);
//        vm.startPrank(manager);
//    }
//
//    function testRemoveAlreadyRemovedProduct() external {
//        uint256 productToUnWhitelist = 20;
//        vault.addProduct(productToUnWhitelist);
//        vm.stopPrank();
//
//        vm.prank(vault.upgrader());
//        vault.removeProduct(productToUnWhitelist);
//
//        vm.prank(vault.upgrader());
//        vm.expectRevert(VaultErrors.ProductIsNotWhitelisted.selector);
//        vault.removeProduct(productToUnWhitelist);
//        vm.startPrank(manager);
//    }
//
//    //    function testUnderlyingBalanceWithInvalidShareAmount() external {
//    //        uint256 shareToQueryUnderlyingBalanceFor = vault.totalSupply() + 1;
//    //        vm.expectRevert(VaultErrors.InvalidShareAmount.selector);
//    //        vault.getUnderlyingBalanceByShares(shareToQueryUnderlyingBalanceFor);
//    //    }
//
//    function testMulticallWithNonManager() external {
//        vm.stopPrank();
//        address[] memory targets = new address[](1);
//        bytes[] memory data = new bytes[](1);
//        targets[0] = address(endpoint);
//        data[0] = '0x';
//        vm.prank(address(0x1));
//        vm.expectRevert(bytes('Ownable: caller is not the manager'));
//        vault.multicallByManager(targets, data);
//        vm.startPrank(manager);
//    }
//
//    function testMulticallWithZeroTargets() external {
//        address[] memory targets = new address[](0);
//        bytes[] memory data = new bytes[](0);
//        vm.expectRevert(VaultErrors.InvalidLength.selector);
//        vault.multicallByManager(targets, data);
//
//        targets = new address[](1);
//        data = new bytes[](0);
//        vm.expectRevert(VaultErrors.InvalidLength.selector);
//        vault.multicallByManager(targets, data);
//    }
//
//    function testMulticallWithDepositTokenAndNonApproveFunction() external {
//        address[] memory targets = new address[](1);
//        bytes[] memory data = new bytes[](1);
//        targets[0] = address(usdc);
//        data[0] = abi.encode(bytes4(uint32(0)));
//        vm.expectRevert(VaultErrors.InvalidMulticall.selector);
//        vault.multicallByManager(targets, data);
//    }
//
//    function testMulticallWithDepositTokenAndApproveFunctionWithNonEndpointAddress() external {
//        address[] memory targets = new address[](1);
//        bytes[] memory data = new bytes[](1);
//        targets[0] = address(usdc);
//        data[0] = abi.encodeWithSelector(usdc.approve.selector, address(0x1), 123);
//        vm.expectRevert(VaultErrors.InvalidMulticall.selector);
//        vault.multicallByManager(targets, data);
//    }
//
//    function testMulticallWithDepositTokenAndApproveFunction() external {
//        address[] memory targets = new address[](1);
//        bytes[] memory data = new bytes[](1);
//        targets[0] = address(usdc);
//        data[0] = abi.encodeWithSelector(usdc.approve.selector, address(endpoint), 123);
//        vault.multicallByManager(targets, data);
//    }
//
//    //    function testMulticallWithEndpoint() external {
//    //        address[] memory targets = new address[](2);
//    //        bytes[] memory data = new bytes[](2);
//    //
//    //        targets[0] = address(usdc);
//    //        data[0] = abi.encodeWithSelector(usdc.approve.selector, address(endpoint), 1_000_000);
//    //        targets[1] = address(endpoint);
//    //        data[1] = vm.envBytes('calldata');
//    //        vault.multicallByManager(targets, data);
//    //    }
//
//    function testMulticallWithNonWhitelistedAddress() external {
//        address[] memory targets = new address[](1);
//        bytes[] memory data = new bytes[](1);
//        targets[0] = address(0x1);
//        data[0] = abi.encode(usdc.approve.selector);
//        vm.expectRevert(VaultErrors.TargetIsNotWhitelisted.selector);
//        vault.multicallByManager(targets, data);
//    }
//
//    function testMulticallWithwEthAndwBTC() external {
//        address[] memory targets = new address[](1);
//        bytes[] memory data = new bytes[](1);
//        targets[0] = address(vault.assets(1));
//        data[0] = abi.encodeWithSelector(usdc.approve.selector, address(0x0), 0);
//        vm.expectRevert(VaultErrors.InvalidMulticall.selector);
//        vault.multicallByManager(targets, data);
//
//        targets[0] = address(vault.assets(2));
//        data[0] = abi.encodeWithSelector(usdc.approve.selector, address(0x0), 0);
//        vm.expectRevert(VaultErrors.InvalidMulticall.selector);
//        vault.multicallByManager(targets, data);
//    }
//
//    //    function testActual() external {
//    ////        address[] memory targets = new address[](1);
//    ////        bytes[] memory data = new bytes[](1);
//    ////        targets[0] = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
//    ////        data[0] = abi.encodeWithSignature(
//    ////            "approve(address,uint256)",
//    ////            0xbbEE07B3e8121227AfCFe1E2B82772246226128e,
//    ////            1000000
//    ////        );
//    //////        address[] memory targets = new address[](1);
//    //////        bytes[] memory data = new bytes[](1);
//    //////        targets[0] = address(usdc);
//    //////        data[0] = abi.encodePacked(bytes4(usdc.approve.selector), abi.encode(address(endpoint), uint256(1000000)));
//    //////        console2.logBytes(abi.encodePacked(bytes4(usdc.approve.selector), abi.encode(address(endpoint), uint256(1000000))));
//    ////        vault.multicallByManager(targets, data);
//    ////        address(vault).call(vm.envBytes("data"));
//    //    }
}
