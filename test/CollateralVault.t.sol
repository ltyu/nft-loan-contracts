// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {CollateralVault} from "../src/CollateralVault.sol";

contract CollateralVaultTest is Test {
    CollateralVault public collateralVault;

    function setUp() public {
        collateralVault = new CollateralVault();
        
    }

    function test_LocksNFT() public {
        
        assertEq(counter.number(), 1);
    }

    
}
