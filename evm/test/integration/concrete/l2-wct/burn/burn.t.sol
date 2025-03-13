// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { L2WCT } from "src/L2WCT.sol";
import { Integration_Test } from "test/integration/Integration.t.sol";
import { INttToken } from "src/interfaces/INttToken.sol";

contract Burn_L2WCT_Integration_Concrete_Test is Integration_Test {
    uint256 internal constant AMOUNT = 100;

    function setUp() public override {
        super.setUp();
        // Mint tokens to the minter
        address minterAddress = l2wct.minter();
        vm.prank(minterAddress);
        l2wct.mint(minterAddress, AMOUNT * 2);
    }

    function test_RevertWhen_CallerNotMinter() external {
        // We need to use burn(uint256) from INttToken, not burn() from ERC20Burnable
        vm.expectRevert(abi.encodeWithSelector(INttToken.CallerNotMinter.selector, users.alice));
        vm.prank(users.alice);
        l2wct.burn(AMOUNT);
    }

    function test_RevertWhen_FromNotWhitelisted() external {
        // Ensure minter is not whitelisted
        address minter = l2wct.minter();
        assertEq(l2wct.allowedFrom(minter), false, "Minter should not be whitelisted as from");
        assertEq(l2wct.allowedTo(address(0)), false, "Zero address should not be whitelisted as to");

        vm.prank(minter);
        vm.expectRevert(L2WCT.TransferRestricted.selector);
        l2wct.burn(AMOUNT);
    }

    function test_Burn_WhenFromWhitelisted() external {
        // Whitelist the minter for transfers
        address minter = l2wct.minter();
        vm.prank(users.manager);
        l2wct.setAllowedFrom(minter, true);

        uint256 initialSupply = l2wct.totalSupply();
        uint256 initialBalance = l2wct.balanceOf(minter);

        vm.prank(minter);
        l2wct.burn(AMOUNT);

        assertEq(l2wct.balanceOf(minter), initialBalance - AMOUNT);
        assertEq(l2wct.totalSupply(), initialSupply - AMOUNT);
    }

    function test_Burn_WhenToWhitelisted() external {
        // Whitelist address(0) for receiving transfers
        vm.prank(users.manager);
        l2wct.setAllowedTo(address(0), true);

        address minter = l2wct.minter();
        uint256 initialSupply = l2wct.totalSupply();
        uint256 initialBalance = l2wct.balanceOf(minter);

        vm.prank(minter);
        l2wct.burn(AMOUNT);

        assertEq(l2wct.balanceOf(minter), initialBalance - AMOUNT);
        assertEq(l2wct.totalSupply(), initialSupply - AMOUNT);
    }

    function test_RevertWhen_FromNotWhitelistedAndToNotWhitelisted() external {
        // Ensure minter is not whitelisted
        address minter = l2wct.minter();
        assertEq(l2wct.allowedFrom(minter), false, "Minter should not be whitelisted as from");
        assertEq(l2wct.allowedTo(address(0)), false, "Zero address should not be whitelisted as to");

        vm.prank(minter);
        vm.expectRevert(L2WCT.TransferRestricted.selector);
        l2wct.burn(AMOUNT);
    }

    function test_Burn_WhenTransferabilityOn() external {
        // Disable transfer restrictions
        vm.prank(users.admin);
        l2wct.disableTransferRestrictions();

        address minter = l2wct.minter();
        uint256 initialSupply = l2wct.totalSupply();
        uint256 initialBalance = l2wct.balanceOf(minter);

        vm.prank(minter);
        l2wct.burn(AMOUNT);

        assertEq(l2wct.balanceOf(minter), initialBalance - AMOUNT);
        assertEq(l2wct.totalSupply(), initialSupply - AMOUNT);
    }
}
