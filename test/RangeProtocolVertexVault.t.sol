//// SPDX-License-Identifier: UNLICENSED
//pragma solidity 0.8.20;
//
//import { Test, console2 } from 'forge-std/Test.sol';
//import { IERC20 } from '@openzeppelin/contracts/interfaces/IERC20.sol';
//
//import { RangeProtocolVertexVault } from '../src/RangeProtocolVertexVault.sol';
//import { ISpotEngine } from '../src/interfaces/vertex/ISpotEngine.sol';
//import { IPerpEngine } from '../src/interfaces/vertex/IPerpEngine.sol';
//import { IEndpoint } from '../src/interfaces/vertex/IEndpoint.sol';
//import { IUSDC } from './IUSDC.sol';
//import { VaultErrors } from '../src/errors/VaultErrors.sol';
//import { FullMath } from '../src/libraries/FullMath.sol';
//
//contract RangeProtocolVertexVaultTest is Test {
//    event Minted(address user, uint256 shares, uint256 amount);
//    event Burned(address user, uint256 shares, uint256 amount);
//    event ProductAdded(uint256 product);
//    event ProductRemoved(uint256 product);
//    event ManagingFeeSet(uint256 managingFee);
//
//    error FailedInnerCall();
//    error EnforcedPause();
//
//    ISpotEngine spotEngine = ISpotEngine(0x32d91Af2B17054D575A7bF1ACfa7615f41CCEfaB);
//    IPerpEngine perpEngine = IPerpEngine(0xb74C78cca0FADAFBeE52B2f48A67eE8c834b5fd1);
//    IEndpoint endpoint = IEndpoint(0xbbEE07B3e8121227AfCFe1E2B82772246226128e);
//    IUSDC usdc = IUSDC(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);
//    IERC20 wETH = IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
//    IERC20 wBTC = IERC20(0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f);
//
//    RangeProtocolVertexVault vault = RangeProtocolVertexVault(0xCb60Ca32B25b4E11cD1959514d77356D58d3E138);
//    address manager = 0xBBE307DB73D8fD981A7dAB929E2a41225CF0658A;
//    address swapRouter = 0xEAd050515E10fDB3540ccD6f8236C46790508A76;
//
//    function setUp() external {
//        uint256 fork = vm.createFork(vm.rpcUrl('arbitrum'));
//        vm.selectFork(fork);
//        vm.prank(0xB38e8c17e38363aF6EbdCb3dAE12e0243582891D);
//        usdc.transfer(manager, 100_000 * 10 ** 6);
//
//        vm.startPrank(manager);
//        vault.upgradeToAndCall(address(new RangeProtocolVertexVault()), abi.encodeWithSignature('reinit()'));
//    }
//
//    function testSwapWithNonWhitelistedTarget() external {
//        bytes memory callData = vm.envBytes('calldata');
//        vm.expectRevert(VaultErrors.SwapRouterIsNotWhitelisted.selector);
//        vault.swap(address(0x123), callData, IERC20(address(0x123)), 0);
//    }
//
//    function testSwapWithinMinimumSwapInterval() external {
//        bytes memory callData = vm.envBytes('calldata');
//        vault.swap(swapRouter, callData, IERC20(address(usdc)), 2000e6);
//
//        vm.expectRevert(VaultErrors.SwapIntervalNotSatisfied.selector);
//        vault.swap(swapRouter, callData, IERC20(address(usdc)), 2000e6);
//    }
//
//    function testSwap() external {
//        bytes memory callData = vm.envBytes('calldata');
//        vm.expectRevert(VaultErrors.SwapThresholdExceeded.selector);
//        vault.swap(swapRouter, callData, IERC20(address(usdc)), 2000e6);
//    }
//
//    function testCallReinitAgain() external {
//        vm.expectRevert();
//        vault.reinit();
//    }
//
//    function testUnderlyingBalance() external {
//        deal(address(wETH), manager, 100_000e18);
//        wETH.transfer(address(vault), 10e18);
//
//        deal(address(wBTC), manager, 100_000e8);
//        wBTC.transfer(address(vault), 10e8);
//        vault.getUnderlyingBalance();
//    }
//
//    function testChangeUpgraderByNonUpgrader() external {
//        vm.expectRevert(VaultErrors.OnlyUpgraderAllowed.selector);
//        vault.changeUpgrader(address(0x1));
//    }
//
//    function testChangeUpgraderAddress() external {
//        assertEq(vault.upgrader(), 0x75a45Bc069F345b424dc67fb37d7079e219AF206);
//        vm.startPrank(0x75a45Bc069F345b424dc67fb37d7079e219AF206);
//        vault.changeUpgrader(address(0x1));
//        assertEq(vault.upgrader(), address(0x1));
//    }
//
//    function testWhitelistSwapRouterByNonUpgrader() external {
//        vm.expectRevert(VaultErrors.OnlyUpgraderAllowed.selector);
//        vault.whiteListSwapRouter(address(0x123));
//    }
//
//    function testWhitelistSwapRouter() external {
//        assertEq(vault.whitelistedSwapRouters(address(0x123)), false);
//        vm.startPrank(0x75a45Bc069F345b424dc67fb37d7079e219AF206);
//        vault.whiteListSwapRouter(address(0x123));
//        assertEq(vault.whitelistedSwapRouters(address(0x123)), true);
//    }
//
//    function testWhitelistTargetByNonUpgrader() external {
//        vm.expectRevert(VaultErrors.OnlyUpgraderAllowed.selector);
//        vault.whiteListTarget(address(0x123));
//    }
//
//    function testWhitelistTarget() external {
//        assertEq(vault.whitelistedTargets(address(0x123)), false);
//        vm.startPrank(0x75a45Bc069F345b424dc67fb37d7079e219AF206);
//        vault.whiteListTarget(address(0x123));
//        assertEq(vault.whitelistedTargets(address(0x123)), true);
//    }
//
//    function testRemoveTargetFromWhitelistByNonUpgrader() external {
//        vm.expectRevert(VaultErrors.OnlyUpgraderAllowed.selector);
//        vault.removeTargetFromWhitelist(address(0x123));
//    }
//
//    function testRemoveTargetFromWhitelist() external {
//        assertEq(vault.whitelistedTargets(address(0x123)), false);
//        vm.startPrank(0x75a45Bc069F345b424dc67fb37d7079e219AF206);
//        vault.whiteListTarget(address(0x123));
//        assertEq(vault.whitelistedTargets(address(0x123)), true);
//
//        vm.startPrank(0x75a45Bc069F345b424dc67fb37d7079e219AF206);
//        vault.removeTargetFromWhitelist(address(0x123));
//        assertEq(vault.whitelistedTargets(address(0x123)), false);
//    }
//
//    function testChangeSwapThresholdByNonUpgrader() external {
//        vm.expectRevert(VaultErrors.OnlyUpgraderAllowed.selector);
//        vault.changeSwapThreshold(9900);
//    }
//
//    function testChangeSwapThreshold() external {
//        assertEq(vault.swapThreshold(), 9995);
//        vm.startPrank(0x75a45Bc069F345b424dc67fb37d7079e219AF206);
//        vault.changeSwapThreshold(9900);
//        assertEq(vault.swapThreshold(), 9900);
//    }
//
//    function testChangeMinimumSwapIntervalByNonUpgrader() external {
//        vm.expectRevert(VaultErrors.OnlyUpgraderAllowed.selector);
//        vault.changeMinimumSwapInterval(2 minutes);
//    }
//
//    function testChangeMinimumSwapInterval() external {
//        assertEq(vault.minimumSwapInterval(), 15 minutes);
//        vm.startPrank(0x75a45Bc069F345b424dc67fb37d7079e219AF206);
//        vault.changeMinimumSwapInterval(2 minutes);
//        assertEq(vault.minimumSwapInterval(), 2 minutes);
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
//        vm.startPrank(manager);
//        uint256 amount = 1e6;
//        usdc.approve(address(vault), amount);
//
//        uint256 vaultBalanceBefore = vault.getUnderlyingBalance();
//        uint256 minShares = vault.getMintAmount(amount);
//        vm.expectEmit();
//        emit Minted(manager, minShares, amount);
//        vault.mint(amount, minShares);
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
//        uint256 expectedAmount = vault.getUnderlyingBalanceByShares(amount);
//
//        vm.expectRevert(VaultErrors.AmountIsLessThanMinAmount.selector);
//        vault.burn(amount, expectedAmount + 100);
//    }
//
//    function testBurnWhenPaused() external {
//        uint256 amount = 1e6;
//        usdc.approve(address(vault), amount);
//        vault.mint(amount, 0);
//
//        vault.pause();
//        vm.expectRevert(EnforcedPause.selector);
//        vault.burn(amount, 0);
//    }
//
//    function testBurn() external {
//        usdc.transfer(address(vault), 100e6);
//        uint256 amount = 10e6;
//
//        usdc.approve(address(vault), amount);
//        vault.mint(amount, 0);
//
//        uint256 expectedAmount = vault.getUnderlyingBalanceByShares(amount);
//        uint256 expectedManagerBalance = vault.managerBalance() + (expectedAmount * 10_000 / 9975) - expectedAmount;
//
//        vm.expectEmit();
//        emit Burned(manager, amount, expectedAmount);
//        vault.burn(amount, expectedAmount);
//
//        assertEq(vault.managerBalance(), expectedManagerBalance);
//        uint256 managerAccountBalanceBefore = usdc.balanceOf(manager);
//        vault.collectManagerFee();
//        assertEq(vault.managerBalance(), 0);
//        assertEq(usdc.balanceOf(manager), managerAccountBalanceBefore + expectedManagerBalance);
//    }
//
//    function testBurnWithZeroRedeemableAmount() external {
//        vm.expectRevert(VaultErrors.ZeroAmountRedeemed.selector);
//        vault.burn(1, 0);
//    }
//
//    function testSetManagingFeeByNonManager() external {
//        vm.stopPrank();
//        vm.prank(address(0x1));
//        vm.expectRevert(bytes('Ownable: caller is not the manager'));
//        vault.setManagingFee(2000);
//        vm.startPrank(manager);
//    }
//
//    function testSetManagerFee() external {
//        assertEq(vault.managingFee(), 25);
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
//    function testUnderlyingBalanceWithInvalidShareAmount() external {
//        uint256 shareToQueryUnderlyingBalanceFor = vault.totalSupply() + 1;
//        vm.expectRevert(VaultErrors.InvalidShareAmount.selector);
//        vault.getUnderlyingBalanceByShares(shareToQueryUnderlyingBalanceFor);
//    }
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
//        targets[0] = address(vault.wETH());
//        data[0] = abi.encode(usdc.approve.selector);
//        vm.expectRevert(VaultErrors.TargetIsNotWhitelisted.selector);
//        vault.multicallByManager(targets, data);
//
//        targets[0] = address(vault.wBTC());
//        data[0] = abi.encode(usdc.approve.selector);
//        vm.expectRevert(VaultErrors.TargetIsNotWhitelisted.selector);
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
//}
