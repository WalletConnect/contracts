// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { MintManager } from "src/MintManager.sol";
import { BRR } from "src/BRR.sol";
import { Integration_Test } from "test/integration/Integration.t.sol";

contract Mint_MintManager_Integration_Fuzz_Test is Integration_Test {
    MintManager internal mintManager;

    function setUp() public override {
        super.setUp();
        vm.startPrank(users.admin);
        mintManager = new MintManager(users.admin, address(brr));
        brr.transferOwnership(address(mintManager));
        vm.stopPrank();

        vm.label(address(mintManager), "MintManager");
    }

    function testFuzz_MintWithRandomAmounts(uint256 amount, uint256 timeElapsed) public {
        vm.assume(amount > 0 && amount <= BRR_MAX_SUPPLY);
        // Prevent overflow for warp
        vm.assume(timeElapsed <= BRR_MAX_SUPPLY);

        uint256 initialSupply = brr.totalSupply();
        uint256 maxMintAmount = (initialSupply * mintManager.MINT_CAP()) / mintManager.DENOMINATOR();

        vm.prank(users.admin);
        mintManager.mint(users.admin, 1); // Set initial mintPermittedAfter

        vm.warp(block.timestamp + timeElapsed);

        if (timeElapsed < mintManager.MINT_PERIOD()) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    MintManager.MintingNotPermittedYet.selector, block.timestamp, mintManager.mintPermittedAfter()
                )
            );
            vm.prank(users.admin);
            mintManager.mint(users.admin, amount);
        } else if (amount <= maxMintAmount) {
            vm.prank(users.admin);
            mintManager.mint(users.admin, amount);
            assertEq(
                brr.balanceOf(users.admin), amount + 1, "User balance should increase by mint amount plus initial mint"
            );
            assertEq(
                brr.totalSupply(),
                initialSupply + amount + 1,
                "Total supply should increase by mint amount plus initial mint"
            );
        } else {
            vm.expectRevert(abi.encodeWithSelector(MintManager.MintAmountExceedsCap.selector, amount, maxMintAmount));
            vm.prank(users.admin);
            mintManager.mint(users.admin, amount);
        }
    }
}
