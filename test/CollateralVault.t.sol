// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {CollateralVault} from "../src/CollateralVault.sol";
import {PunkNFT} from "../src/mocks/MockERC721.sol";
import {StableToken} from "../src/mocks/MockERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "forge-std/console.sol";
contract CollateralVaultTest is Test {
    CollateralVault public collateralVault;
    ERC721 acceptedNFT;
    StableToken usdc;
    address stableVault = address(777);
    address alice = address(0x1E176c822Bec0BE7581C0e31cF3A80f1bB075d76);

    function setUp() public {
        // chainId should  match frontend test
        vm.chainId(5);
        acceptedNFT = new PunkNFT(alice);
        usdc = new StableToken();
        usdc.mint(alice, 1000 ether);
        collateralVault = new CollateralVault(address(acceptedNFT), address(usdc), alice);
    }

    function test_LocksNFT() public {
        vm.startPrank(alice);
        acceptedNFT.approve(address(collateralVault), 1);
        collateralVault.depositNFT(1);
        vm.stopPrank();
        assertEq(acceptedNFT.ownerOf(1), address(collateralVault));
    }

    function test_onlyBorrowerCanBorrow() public {
        vm.expectRevert(CollateralVault.NotBorrower.selector);
        collateralVault.borrow(1 ether);
    }

    function test_borrowUpToPrice() public {
        usdc.mint(address(collateralVault), 10 ether);

        vm.startPrank(alice);
        acceptedNFT.approve(address(collateralVault), 1);
        collateralVault.depositNFT(1);
        collateralVault.borrow(1 ether);
        vm.stopPrank();

        assertEq(usdc.balanceOf(alice), 1001 ether);
    }

    function test_priceDropCausesLiquidatable() public {
        usdc.mint(address(collateralVault), 101 ether);

        vm.startPrank(alice);
        acceptedNFT.approve(address(collateralVault), 1);
        collateralVault.depositNFT(1);
        collateralVault.borrow(100 ether);
        vm.stopPrank();

        assertEq(collateralVault.isLiquidatable(), false);
        collateralVault.setPrice(0);
        assertEq(collateralVault.isLiquidatable(), true);
    }

    function test_repayingLoanUsing721ReturnsCorrectUser() public {
        test_LocksNFT();

        // v, r, s has been pre-computed via ethers.js
        uint8 v = 28;
        bytes32 r = bytes32(abi.encodePacked(hex"c38603bf329a9718f18b63a37d1d7994be4db90d29e74aad1f46ba455d447962"));
        bytes32 s = bytes32(abi.encodePacked(hex"2eec5971f5f34d5da8cdd7d1c3155a06bbca82b29756e7189ca802d4714cdcd4"));

        uint256 balanceBefore = usdc.balanceOf(alice);
        vm.prank(alice);
        usdc.approve(address(collateralVault), 1000 ether);

        address signer = collateralVault.repayPermit(alice, v, r, s);
        uint256 balanceAfter = usdc.balanceOf(alice);

        assertEq(signer, alice);
        assertEq(balanceAfter + 1 ether, balanceBefore);
        assertEq(acceptedNFT.ownerOf(1), address(alice));
    }
}
