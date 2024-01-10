// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Test, console2 } from 'forge-std/Test.sol';
import { stdStorage, StdStorage } from 'forge-std/Test.sol';

import { RangeProtocolVertexVault } from '../src/RangeProtocolVertexVault.sol';
import { ISpotEngine } from '../src/interfaces/vertex/ISpotEngine.sol';
import { IPerpEngine } from '../src/interfaces/vertex/IPerpEngine.sol';
import { IEndPoint } from '../src/interfaces/vertex/IEndPoint.sol';
import { IUSDC } from './IUSDC.sol';
import { VaultErrors } from '../src/errors/VaultErrors.sol';
import { FullMath } from '../src/libraries/FullMath.sol';

contract RangeProtocolVertexVaultTest is Test {
    using stdStorage for StdStorage;

    event Minted(address user, uint256 shares, uint256 amount);
    event Burned(address user, uint256 shares, uint256 amount);
    event ProductAdded(uint256 product);
    event ProductRemoved(uint256 product);
    event ManagingFeeSet(uint256 managingFee);

    error FailedInnerCall();

    ISpotEngine spotEngine =
        ISpotEngine(0x32d91Af2B17054D575A7bF1ACfa7615f41CCEfaB);
    IPerpEngine perpEngine =
        IPerpEngine(0xb74C78cca0FADAFBeE52B2f48A67eE8c834b5fd1);
    IEndPoint endPoint = IEndPoint(0xbbEE07B3e8121227AfCFe1E2B82772246226128e);
    IUSDC usdc = IUSDC(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);

    RangeProtocolVertexVault vault =
        RangeProtocolVertexVault(0xCb60Ca32B25b4E11cD1959514d77356D58d3E138);
    address manager = 0x2B986A355F5676F77687A84b3209Af8654b2C6aa;

    function setUp() external {
        vm.startPrank(manager);
        uint256 fork = vm.createFork(vm.rpcUrl('arbitrum'));
        vm.selectFork(fork);
        deal(address(usdc), manager, 100_000 * 10 ** 6);

        vault.upgradeToAndCall(address(new RangeProtocolVertexVault()), '');
    }

    function testMintWithZeroAmount() external {
        vm.expectRevert(VaultErrors.ZeroMintAmount.selector);
        vault.mint(0);
    }

    function testMintWithoutApprove() external {
        uint256 amount = 1000 * 10 ** 6;
        vm.expectRevert(bytes('ERC20: transfer amount exceeds allowance'));
        vault.mint(amount);
    }

    function testMint() external {
        uint256 amount = 1000 * 10 ** 6;
        usdc.approve(address(vault), amount);

        uint256 vaultBalanceBefore = vault.getUnderlyingBalance();
        vm.expectEmit();
        emit Minted(
            manager,
            FullMath.mulDivRoundingUp(
                amount, vault.totalSupply(), vault.getUnderlyingBalance()
            ),
            amount
        );
        vault.mint(amount);
        assertEq(vault.getUnderlyingBalance(), vaultBalanceBefore + amount);
    }

    function testBurnZeroAmount() external {
        vm.expectRevert(VaultErrors.ZeroBurnAmount.selector);
        vault.burn(0);
    }

    function testBurnWithoutOwningShares() external {
        vm.stopPrank();
        vm.prank(address(0x1));
        vm.expectRevert();
        vault.burn(1000);
        vm.startPrank(manager);
    }

    function testBurn() external {
        uint256 amount = vault.balanceOf(manager) * 8000 / 10_000;
        uint256 expectedAmount = vault.getUnderlyingBalanceByShare(amount);
        uint256 expectedManagerBalance = vault.managerBalance()
            + (expectedAmount * 10_000 / 9900) - expectedAmount;

        vm.expectEmit();
        emit Burned(manager, amount, expectedAmount);
        vault.burn(amount);

        assertEq(vault.managerBalance(), expectedManagerBalance);
        uint256 managerAccountBalanceBefore = usdc.balanceOf(manager);
        vault.collectManagerFee();
        assertEq(vault.managerBalance(), 0);
        assertEq(
            usdc.balanceOf(manager),
            managerAccountBalanceBefore + expectedManagerBalance
        );
    }

    //    function testBurnWithZeroRedeemableAmount() external {
    //        vm.expectRevert(VaultErrors.ZeroAmountRedeemed.selector);
    //        vault.burn(1);
    //    }

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
        vm.prank(address(0x0));
        vm.expectRevert(bytes('Ownable: caller is not the manager'));
        vault.removeProduct(productToUnWhitelist);
        vm.startPrank(manager);
    }

    function testRemoveProduct() external {
        uint256 productToUnWhitelist = 20;
        vault.addProduct(productToUnWhitelist);
        assertEq(vault.isWhiteListedProduct(productToUnWhitelist), true);
        vault.removeProduct(productToUnWhitelist);
        assertEq(vault.isWhiteListedProduct(productToUnWhitelist), false);
    }

    function testRemoveAlreadyRemovedProduct() external {
        uint256 productToUnWhitelist = 20;
        vault.addProduct(productToUnWhitelist);
        vault.removeProduct(productToUnWhitelist);
        vm.expectRevert(VaultErrors.ProductIsNotWhitelisted.selector);
        vault.removeProduct(productToUnWhitelist);
    }

    function testUnderlyingBalanceWithInvalidShareAmount() external {
        uint256 shareToQueryUnderlyingBalanceFor = vault.totalSupply() + 1;
        vm.expectRevert(VaultErrors.InvalidShareAmount.selector);
        vault.getUnderlyingBalanceByShare(shareToQueryUnderlyingBalanceFor);
    }

    function testMulticallWithNonManager() external {
        vm.stopPrank();
        address[] memory targets = new address[](1);
        bytes[] memory data = new bytes[](1);
        targets[0] = address(endPoint);
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

    function testMulticallWithInvalidTarget() external {
        address[] memory targets = new address[](1);
        bytes[] memory data = new bytes[](1);
        vm.expectRevert(VaultErrors.InvalidMulticallTarget.selector);
        vault.multicallByManager(targets, data);
    }

    function testMulticallWithDepositTokenAndNonApproveFunction() external {
        address[] memory targets = new address[](1);
        bytes[] memory data = new bytes[](1);
        targets[0] = address(usdc);
        data[0] = abi.encode(bytes4(uint32(0)));
        vm.expectRevert(
            VaultErrors.OnlyApproveCallIsAllowedOnDepositToken.selector
        );
        vault.multicallByManager(targets, data);
    }

    function testMulticallWithDepositTokenAndApproveFunction() external {
        address[] memory targets = new address[](1);
        bytes[] memory data = new bytes[](1);
        targets[0] = address(usdc);
        data[0] = abi.encode(usdc.approve.selector);
        console2.logBytes(data[0]);
        vm.expectRevert(FailedInnerCall.selector);
        vault.multicallByManager(targets, data);
    }

    function testMulticallWithEndpoint() external {
        address[] memory targets = new address[](1);
        bytes[] memory data = new bytes[](1);
        targets[0] = address(endPoint);
        data[0] = abi.encode(usdc.approve.selector);
        vm.expectRevert(FailedInnerCall.selector);
        vault.multicallByManager(targets, data);
    }

    //    function testActual() external {
    ////        address[] memory targets = new address[](1);
    ////        bytes[] memory data = new bytes[](1);
    ////        targets[0] = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    ////        data[0] = abi.encodeWithSignature(
    ////            "approve(address,uint256)",
    ////            0xbbEE07B3e8121227AfCFe1E2B82772246226128e,
    ////            1000000
    ////        );
    //////        address[] memory targets = new address[](1);
    //////        bytes[] memory data = new bytes[](1);
    //////        targets[0] = address(usdc);
    //////        data[0] = abi.encodePacked(bytes4(usdc.approve.selector), abi.encode(address(endPoint), uint256(1000000)));
    //////        console2.logBytes(abi.encodePacked(bytes4(usdc.approve.selector), abi.encode(address(endPoint), uint256(1000000))));
    ////        vault.multicallByManager(targets, data);
    ////        address(vault).call(vm.envBytes("data"));
    //    }
}
