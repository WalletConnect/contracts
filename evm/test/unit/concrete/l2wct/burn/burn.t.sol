// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { L2WCT } from "src/L2WCT.sol";
import { INttToken } from "src/interfaces/INttToken.sol";
import { Base_Test } from "../../../../Base.t.sol";
import { IERC20Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

contract Burn_L2WCT_Unit_Concrete_Test is Base_Test {
    uint256 internal constant BURN_AMOUNT = 100;

    function setUp() public override {
        super.setUp();
        deployCoreConditionally();

        // Mint tokens to the minter for burning
        address minterAddress = l2wct.minter();
        vm.prank(minterAddress);
        l2wct.mint(minterAddress, BURN_AMOUNT * 2);

        // Attacker has tokens to burn
        deal(address(l2wct), users.attacker, BURN_AMOUNT);
    }

    function test_RevertWhen_CallerNotMinterAndFromWhitelisted() external {
        // Whitelist the attacker for transfers
        vm.prank(users.manager);
        l2wct.setAllowedFrom(users.attacker, true);

        // Make the attacker the caller
        vm.prank(users.attacker);

        // Run the test
        vm.expectRevert(abi.encodeWithSelector(INttToken.CallerNotMinter.selector, users.attacker));
        l2wct.burn(BURN_AMOUNT);
    }

    function test_RevertWhen_CallerNotMinterAndToWhitelisted() external {
        // Whitelist address(0) for receiving transfers
        vm.prank(users.manager);
        l2wct.setAllowedTo(address(0), true);

        // Make the attacker the caller
        vm.prank(users.attacker);

        // Run the test
        vm.expectRevert(abi.encodeWithSelector(INttToken.CallerNotMinter.selector, users.attacker));
        l2wct.burn(BURN_AMOUNT);
    }

    function test_RevertWhen_CallerNotMinterAndTransferabilityOn() external {
        // Disable transfer restrictions
        vm.prank(users.admin);
        l2wct.disableTransferRestrictions();

        // Make the attacker the caller
        vm.prank(users.attacker);

        // Run the test
        vm.expectRevert(abi.encodeWithSelector(INttToken.CallerNotMinter.selector, users.attacker));
        l2wct.burn(BURN_AMOUNT);
    }

    function test_RevertWhen_FromNotWhitelistedAndToNotWhitelisted() external {
        // Ensure the minter is not whitelisted
        address minter = l2wct.minter();

        // Verify the minter is not whitelisted
        assertEq(l2wct.allowedFrom(minter), false, "Minter should not be whitelisted as from");
        assertEq(l2wct.allowedTo(address(0)), false, "Zero address should not be whitelisted as to");

        // Expect revert due to transfer restrictions
        vm.prank(minter);
        vm.expectRevert(L2WCT.TransferRestricted.selector);
        l2wct.burn(BURN_AMOUNT);
    }

    function test_BurnWhenFromWhitelisted() external {
        // Whitelist the minter for transfers
        address minter = l2wct.minter();
        vm.prank(users.manager);
        l2wct.setAllowedFrom(minter, true);

        // Get initial state
        uint256 initialSupply = l2wct.totalSupply();
        uint256 initialBalance = l2wct.balanceOf(minter);

        // Expect Transfer event
        vm.expectEmit(true, true, true, true);
        emit Transfer(minter, address(0), BURN_AMOUNT);

        // Burn tokens as minter
        vm.prank(minter);
        l2wct.burn(BURN_AMOUNT);

        // Assert the tokens were burned
        assertEq(l2wct.balanceOf(minter), initialBalance - BURN_AMOUNT, "Balance should decrease");
        assertEq(l2wct.totalSupply(), initialSupply - BURN_AMOUNT, "Total supply should decrease");
    }

    function test_BurnWhenToWhitelisted() external {
        // Whitelist address(0) for receiving transfers
        vm.prank(users.manager);
        l2wct.setAllowedTo(address(0), true);

        // Get initial state
        address minter = l2wct.minter();
        uint256 initialSupply = l2wct.totalSupply();
        uint256 initialBalance = l2wct.balanceOf(minter);

        // Expect Transfer event
        vm.expectEmit(true, true, true, true);
        emit Transfer(minter, address(0), BURN_AMOUNT);

        // Burn tokens as minter
        vm.prank(minter);
        l2wct.burn(BURN_AMOUNT);

        // Assert the tokens were burned
        assertEq(l2wct.balanceOf(minter), initialBalance - BURN_AMOUNT, "Balance should decrease");
        assertEq(l2wct.totalSupply(), initialSupply - BURN_AMOUNT, "Total supply should decrease");
    }

    function test_BurnWhenTransferabilityOn() external {
        // Disable transfer restrictions
        vm.prank(users.admin);
        l2wct.disableTransferRestrictions();

        // Get initial state
        address minter = l2wct.minter();
        uint256 initialSupply = l2wct.totalSupply();
        uint256 initialBalance = l2wct.balanceOf(minter);

        // Expect Transfer event
        vm.expectEmit(true, true, true, true);
        emit Transfer(minter, address(0), BURN_AMOUNT);

        // Burn tokens as minter
        vm.prank(minter);
        l2wct.burn(BURN_AMOUNT);

        // Assert the tokens were burned
        assertEq(l2wct.balanceOf(minter), initialBalance - BURN_AMOUNT, "Balance should decrease");
        assertEq(l2wct.totalSupply(), initialSupply - BURN_AMOUNT, "Total supply should decrease");
    }

    function test_RevertWhen_InsufficientBalance() external {
        // Disable transfer restrictions
        vm.prank(users.admin);
        l2wct.disableTransferRestrictions();

        // Burn all tokens first
        address minter = l2wct.minter();
        uint256 balance = l2wct.balanceOf(minter);
        vm.prank(minter);
        l2wct.burn(balance);

        // Now try to burn more
        vm.prank(minter);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, minter, 0, BURN_AMOUNT));
        l2wct.burn(BURN_AMOUNT);
    }
}
