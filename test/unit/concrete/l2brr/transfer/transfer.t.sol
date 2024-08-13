// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { L2BRR } from "src/L2BRR.sol";
import { IERC20Errors } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Base_Test } from "test/Base.t.sol";

contract Transfer_L2BRR_Unit_Concrete_Test is Base_Test {
    function setUp() public override {
        super.setUp();
        deployCoreConditionally();
        vm.prank(address(mockBridge));
        l2brr.mint(users.alice, 1000);
    }

    modifier givenTransferRestrictionsEnabled() {
        // These are the default values
        _;
    }

    modifier givenTransferRestrictionsDisabled() {
        vm.prank(users.admin);
        l2brr.disableTransferRestrictions();
        _;
    }

    modifier whenSenderNotInAllowedFromList() {
        _;
    }

    modifier whenSenderInAllowedFromList() {
        vm.prank(users.admin);
        l2brr.setAllowedFrom(users.alice, true);
        _;
    }

    modifier whenRecipientNotInAllowedToList() {
        _;
    }

    modifier whenRecipientInAllowedToList() {
        vm.prank(users.admin);
        l2brr.setAllowedTo(users.bob, true);
        _;
    }

    modifier givenSenderHasSufficientBalance() {
        _;
    }

    modifier givenSenderHasInsufficientBalance() {
        _;
    }

    function test_RevertWhen_SenderNotAllowedAndRecipientNotAllowed()
        external
        givenTransferRestrictionsEnabled
        whenSenderNotInAllowedFromList
        whenRecipientNotInAllowedToList
    {
        vm.prank(users.alice);
        vm.expectRevert("L2BRR._update: from or to must be whitelisted");
        l2brr.transfer(users.bob, 100);
    }

    function test_TransferWhen_RecipientInAllowedToList()
        external
        givenTransferRestrictionsEnabled
        whenSenderNotInAllowedFromList
        whenRecipientInAllowedToList
    {
        uint256 initialBalanceAlice = l2brr.balanceOf(users.alice);
        uint256 initialBalanceBob = l2brr.balanceOf(users.bob);

        vm.prank(users.alice);
        vm.expectEmit(true, true, true, true);
        emit Transfer(users.alice, users.bob, 100);

        bool success = l2brr.transfer(users.bob, 100);

        assertTrue(success);
        assertEq(l2brr.balanceOf(users.alice), initialBalanceAlice - 100);
        assertEq(l2brr.balanceOf(users.bob), initialBalanceBob + 100);
    }

    function test_TransferWhen_SenderInAllowedFromList()
        external
        givenTransferRestrictionsEnabled
        whenSenderInAllowedFromList
    {
        uint256 initialBalanceAlice = l2brr.balanceOf(users.alice);
        uint256 initialBalanceBob = l2brr.balanceOf(users.bob);

        vm.prank(users.alice);
        vm.expectEmit(true, true, true, true);
        emit Transfer(users.alice, users.bob, 100);

        bool success = l2brr.transfer(users.bob, 100);

        assertTrue(success);
        assertEq(l2brr.balanceOf(users.alice), initialBalanceAlice - 100);
        assertEq(l2brr.balanceOf(users.bob), initialBalanceBob + 100);
    }

    function test_RevertWhen_SenderInAllowedFromListButInsufficientBalance()
        external
        givenTransferRestrictionsEnabled
        whenSenderInAllowedFromList
        givenSenderHasInsufficientBalance
    {
        vm.prank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, users.alice, 1000, 1001));
        l2brr.transfer(users.bob, 1001);
    }

    function test_TransferWhen_RestrictionsDisabled()
        external
        givenTransferRestrictionsDisabled
        givenSenderHasSufficientBalance
    {
        uint256 initialBalanceAlice = l2brr.balanceOf(users.alice);
        uint256 initialBalanceBob = l2brr.balanceOf(users.bob);

        vm.prank(users.alice);
        vm.expectEmit(true, true, true, true);
        emit Transfer(users.alice, users.bob, 100);

        bool success = l2brr.transfer(users.bob, 100);

        assertTrue(success);
        assertEq(l2brr.balanceOf(users.alice), initialBalanceAlice - 100);
        assertEq(l2brr.balanceOf(users.bob), initialBalanceBob + 100);
    }

    function test_RevertWhen_RestrictionsDisabledButInsufficientBalance()
        external
        givenTransferRestrictionsDisabled
        givenSenderHasInsufficientBalance
    {
        vm.prank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, users.alice, 1000, 1001));
        l2brr.transfer(users.bob, 1001);
    }
}
