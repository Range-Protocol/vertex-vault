// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Test, console2 } from 'forge-std/Test.sol';
import { IERC20 } from '@openzeppelin/contracts/interfaces/IERC20.sol';

import { RangeProtocolVertexVault } from '../src/RangeProtocolVertexVault.sol';
import { ISpotEngine } from '../src/interfaces/vertex/ISpotEngine.sol';
import { IPerpEngine } from '../src/interfaces/vertex/IPerpEngine.sol';
import { IEndpoint } from '../src/interfaces/vertex/IEndpoint.sol';
import { VaultErrors } from '../src/errors/VaultErrors.sol';
import { FullMath } from '../src/libraries/FullMath.sol';
import { ERC1967Proxy } from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';

contract RangeProtocolVertexVaultTest is Test {
    event Minted(address user, uint256 shares, uint256 amount);
    event Burned(address user, uint256 shares, uint256 amount);
    event ProductAdded(uint256 product);
    event ProductRemoved(uint256 product);
    event ManagingFeeSet(uint256 managingFee);

    error FailedInnerCall();
    error EnforcedPause();

    ISpotEngine spotEngine = ISpotEngine(0x57c1AB256403532d02D1150C5790423967B22Bf2);
    IPerpEngine perpEngine = IPerpEngine(0x0bc0c84976e21aaF7bE71d318eD93A5f5c9978A4);
    IEndpoint endpoint = IEndpoint(0x00F076FE36f2341A1054B16ae05FcE0C65180DeD);
    IERC20 usdb = IERC20(0x4300000000000000000000000000000000000003);

    RangeProtocolVertexVault vault;
    address manager = 0xBBE307DB73D8fD981A7dAB929E2a41225CF0658A;

    function setUp() external {
//        vm.createSelectFork(vm.rpcUrl('https://blast.din.dev/rpc'));
//        vm.prank(0x020cA66C30beC2c4Fe3861a94E4DB4A498A35872);
//        usdb.transfer(manager, 100_000 * 10 ** 18);
    }

        function testUnderlyingBalance() external {
            vm.createSelectFork(vm.rpcUrl('https://blast.din.dev/rpc'), 1012778 - 1);
            address vaultImpl = address(new RangeProtocolVertexVault());
            vault = RangeProtocolVertexVault(0xEFef412324F7Df385ddb0014FB0Ae91E531C227b);
            vm.prank(manager);
            vault.upgradeToAndCall(vaultImpl, "");
            vault.getUnderlyingBalance();
            for (uint256 i = 1; i < 15; i++) {
                vm.createSelectFork(vm.rpcUrl('https://blast.din.dev/rpc'), (1012778 + i));
                address vaultImpl = address(new RangeProtocolVertexVault());
                vault = RangeProtocolVertexVault(0xEFef412324F7Df385ddb0014FB0Ae91E531C227b);
                vm.prank(manager);
                vault.upgradeToAndCall(vaultImpl, "");
                vault.getUnderlyingBalance();
            }
        }
    //
//    function testChangeUpgraderByNonUpgrader() external {
//        vm.expectRevert(VaultErrors.OnlyUpgraderAllowed.selector);
//        vm.prank(address(0x1));
//        vault.changeUpgrader(address(0x1));
//    }
//
//    function testChangeUpgraderAddress() external {
//        vm.startPrank(manager);
//        assertEq(vault.upgrader(), manager);
//        vault.changeUpgrader(address(0x1));
//        assertEq(vault.upgrader(), address(0x1));
//        vm.stopPrank();
//    }
//
//    function testWhitelistTargetByNonUpgrader() external {
//        vm.expectRevert(VaultErrors.OnlyUpgraderAllowed.selector);
//        vault.whiteListTarget(address(0x123));
//    }
//
//    function testWhitelistTarget() external {
//        vm.startPrank(manager);
//        assertEq(vault.whitelistedTargets(address(0x123)), false);
//        vault.whiteListTarget(address(0x123));
//        assertEq(vault.whitelistedTargets(address(0x123)), true);
//        vm.stopPrank();
//    }
//
//    function testRemoveTargetFromWhitelistByNonUpgrader() external {
//        vm.expectRevert(VaultErrors.OnlyUpgraderAllowed.selector);
//        vault.removeTargetFromWhitelist(address(0x123));
//    }
//
//    function testRemoveTargetFromWhitelist() external {
//        vm.startPrank(manager);
//        assertEq(vault.whitelistedTargets(address(0x123)), false);
//        vault.whiteListTarget(address(0x123));
//        assertEq(vault.whitelistedTargets(address(0x123)), true);
//
//        vault.removeTargetFromWhitelist(address(0x123));
//        assertEq(vault.whitelistedTargets(address(0x123)), false);
//        vm.stopPrank();
//    }
//
//    function testMintWithZeroAmount() external {
//        vm.expectRevert(VaultErrors.ZeroDepositAmount.selector);
//        vault.mint(0, 0);
//    }
//
//    //    function testMintWithoutApprove() external {
//    //        uint256 amount = 1000 * 10 ** 6;
//    //        vm.expectRevert(bytes('ERC20: transfer amount exceeds allowance'));
//    //        vault.mint(amount, 0);
//    //    }
//
//    function testMintWhenPaused() external {
//        vm.startPrank(manager);
//        vault.pause();
//        uint256 amount = 1000 * 10 ** 6;
//        vm.expectRevert(EnforcedPause.selector);
//        vault.mint(amount, 0);
//        vm.stopPrank();
//    }
//
//    function testMint() external {
//        vm.startPrank(manager);
//        uint256 amount = 1e6;
//        usdb.approve(address(vault), amount);
//
//        uint256 vaultBalanceBefore = vault.getUnderlyingBalance();
//        vm.expectEmit();
//        emit Minted(manager, amount, amount);
//        vault.mint(amount, amount);
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
//        vm.prank(address(0x1));
//        vm.expectRevert();
//        vault.burn(1000, 0);
//    }
//
//    function testBurnWithMoreThanExpectedAmount() external {
//        vm.startPrank(manager);
//        uint256 amount = 1e6;
//        usdb.approve(address(vault), amount);
//        vault.mint(amount, 0);
//        uint256 expectedAmount = vault.getUnderlyingBalanceByShares(amount);
//
//        vm.expectRevert(VaultErrors.AmountIsLessThanMinAmount.selector);
//        vault.burn(amount, expectedAmount + 100);
//        vm.stopPrank();
//    }
//
//    function testBurnWhenPaused() external {
//        vm.startPrank(manager);
//        uint256 amount = 1e6;
//        usdb.approve(address(vault), amount);
//        vault.mint(amount, 0);
//
//        vault.pause();
//        vm.expectRevert(EnforcedPause.selector);
//        vault.burn(amount, 0);
//        vm.stopPrank();
//    }
//
//    function testBurn() external {
//        vm.startPrank(manager);
//        usdb.transfer(address(vault), 100e6);
//        uint256 amount = 10e6;
//
//        usdb.approve(address(vault), amount);
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
//        uint256 managerAccountBalanceBefore = usdb.balanceOf(manager);
//        vault.collectManagerFee();
//        assertEq(vault.managerBalance(), 0);
//        assertEq(usdb.balanceOf(manager), managerAccountBalanceBefore + expectedManagerBalance);
//        vm.stopPrank();
//    }
//
//    //    function testBurnWithZeroRedeemableAmount() external {
//    //        vm.expectRevert(VaultErrors.ZeroAmountRedeemed.selector);
//    //        vault.burn(1, 0);
//    //    }
//
//    function testSetManagingFeeByNonManager() external {
//        vm.prank(address(0x1));
//        vm.expectRevert(bytes('Ownable: caller is not the manager'));
//        vault.setManagingFee(2000);
//    }
//
//    function testSetManagerFee() external {
//        vm.startPrank(manager);
//        assertEq(vault.managingFee(), 25);
//        vault.setManagingFee(200);
//        assertEq(vault.managingFee(), 200);
//        vm.stopPrank();
//    }
//
//    function testSetInvalidManagerFee() external {
//        vm.startPrank(manager);
//        uint256 feeToSet = vault.MAX_MANAGING_FEE() + 1;
//        vm.expectRevert(VaultErrors.InvalidManagingFee.selector);
//        vault.setManagingFee(feeToSet);
//        vm.stopPrank();
//    }
//
//    function testAddProductByNonManager() external {
//        vm.prank(address(0x1));
//        vm.expectRevert(bytes('Ownable: caller is not the manager'));
//        vault.addProduct(20);
//    }
//
//    function testAddProduct() external {
//        vm.startPrank(manager);
//        uint256 productToWhitelist = 20;
//        assertEq(vault.isWhiteListedProduct(productToWhitelist), false);
//        vault.addProduct(productToWhitelist);
//        assertEq(vault.isWhiteListedProduct(productToWhitelist), true);
//        vm.stopPrank();
//    }
//
//    function testAddSameProductTwice() external {
//        vm.startPrank(manager);
//        uint256 productToWhitelist = 20;
//        vault.addProduct(productToWhitelist);
//        vm.expectRevert(VaultErrors.ProductAlreadyWhitelisted.selector);
//        vault.addProduct(productToWhitelist);
//        vm.stopPrank();
//    }
//
//    function testRemoveProductByNonManager() external {
//        vm.startPrank(manager);
//        uint256 productToUnWhitelist = 20;
//        vault.addProduct(productToUnWhitelist);
//        assertEq(vault.isWhiteListedProduct(productToUnWhitelist), true);
//        vm.stopPrank();
//        vm.expectRevert(VaultErrors.OnlyUpgraderAllowed.selector);
//        vault.removeProduct(productToUnWhitelist);
//    }
//
//    function testRemoveProduct() external {
//        vm.startPrank(manager);
//        uint256 productToUnWhitelist = 20;
//        vault.addProduct(productToUnWhitelist);
//        vm.stopPrank();
//
//        assertEq(vault.isWhiteListedProduct(productToUnWhitelist), true);
//        vm.prank(vault.upgrader());
//        vault.removeProduct(productToUnWhitelist);
//        assertEq(vault.isWhiteListedProduct(productToUnWhitelist), false);
//    }
//
//    function testRemoveAlreadyRemovedProduct() external {
//        vm.startPrank(manager);
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
//    }
//
////    function testUnderlyingBalanceWithInvalidShareAmount() external {
////        uint256 shareToQueryUnderlyingBalanceFor = vault.totalSupply() + 1;
////        vm.expectRevert(VaultErrors.InvalidShareAmount.selector);
////        vault.getUnderlyingBalanceByShares(shareToQueryUnderlyingBalanceFor);
////    }
//
//    function testMulticallWithNonManager() external {
//        address[] memory targets = new address[](1);
//        bytes[] memory data = new bytes[](1);
//        targets[0] = address(endpoint);
//        data[0] = '0x';
//        vm.prank(address(0x1));
//        vm.expectRevert(bytes('Ownable: caller is not the manager'));
//        vault.multicallByManager(targets, data);
//    }
//
//    function testMulticallWithZeroTargets() external {
//        vm.startPrank(manager);
//        address[] memory targets = new address[](0);
//        bytes[] memory data = new bytes[](0);
//        vm.expectRevert(VaultErrors.InvalidLength.selector);
//        vault.multicallByManager(targets, data);
//
//        targets = new address[](1);
//        data = new bytes[](0);
//        vm.expectRevert(VaultErrors.InvalidLength.selector);
//        vault.multicallByManager(targets, data);
//        vm.stopPrank();
//    }
//
//    function testMulticallWithDepositTokenAndNonApproveFunction() external {
//        vm.startPrank(manager);
//        address[] memory targets = new address[](1);
//        bytes[] memory data = new bytes[](1);
//        targets[0] = address(usdb);
//        data[0] = abi.encode(bytes4(uint32(0)));
//        vm.expectRevert(VaultErrors.InvalidMulticall.selector);
//        vault.multicallByManager(targets, data);
//        vm.stopPrank();
//    }
//
//    function testMulticallWithDepositTokenAndApproveFunctionWithNonEndpointAddress() external {
//        vm.startPrank(manager);
//        address[] memory targets = new address[](1);
//        bytes[] memory data = new bytes[](1);
//        targets[0] = address(usdb);
//        data[0] = abi.encodeWithSelector(usdb.approve.selector, address(0x1), 123);
//        vm.expectRevert(VaultErrors.InvalidMulticall.selector);
//        vault.multicallByManager(targets, data);
//        vm.stopPrank();
//    }
//
//    function testMulticallWithDepositTokenAndApproveFunction() external {
//        vm.startPrank(manager);
//        address[] memory targets = new address[](1);
//        bytes[] memory data = new bytes[](1);
//        targets[0] = address(usdb);
//        data[0] = abi.encodeWithSelector(usdb.approve.selector, address(endpoint), 123);
//        vault.multicallByManager(targets, data);
//        vm.stopPrank();
//    }
//
//    function testMulticallWithEndpoint() external {
//        vm.startPrank(manager);
//        usdb.transfer(address(vault), 1000000);
//
//        address[] memory targets = new address[](2);
//        bytes[] memory data = new bytes[](2);
//
//        targets[0] = address(usdb);
//        data[0] = abi.encodeWithSelector(usdb.approve.selector, address(endpoint), 1_000_000);
//        targets[1] = address(endpoint);
//        data[1] = vm.envBytes('calldata');
//        vault.multicallByManager(targets, data);
//        vm.stopPrank();
//    }
//
//    function testMulticallWithNonWhitelistedAddress() external {
//        vm.startPrank(manager);
//        address[] memory targets = new address[](1);
//        bytes[] memory data = new bytes[](1);
//        targets[0] = address(0x1);
//        data[0] = abi.encode(usdb.approve.selector);
//        vm.expectRevert(VaultErrors.TargetIsNotWhitelisted.selector);
//        vault.multicallByManager(targets, data);
//        vm.stopPrank();
//    }

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
    //////        targets[0] = address(usdb);
    //////        data[0] = abi.encodePacked(bytes4(usdb.approve.selector), abi.encode(address(endpoint), uint256(1000000)));
    //////        console2.logBytes(abi.encodePacked(bytes4(usdb.approve.selector), abi.encode(address(endpoint), uint256(1000000))));
    ////        vault.multicallByManager(targets, data);
    ////        address(vault).call(vm.envBytes("data"));
    //    }
}
