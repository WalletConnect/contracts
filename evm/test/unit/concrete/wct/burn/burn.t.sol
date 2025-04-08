// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { WCT } from "src/WCT.sol";
import { INttToken } from "src/interfaces/INttToken.sol";
import { Base_Test } from "test/Base.t.sol";

contract Burn_WCT_Unit_Concrete_Test is Base_Test {
    uint256 initialMintAmount = 1000 ether;
    address minter;

    function setUp() public override {
        super.setUp();

        minter = users.bob; // Use Bob as the designated minter for tests
        deployCoreConditionally();

        // Set Bob as the initial minter using the admin account
        vm.prank(users.admin);
        wct.setMinter(minter);

        // Mint some initial tokens to the minter address for burn tests
        vm.startPrank(minter);
        wct.mint(minter, initialMintAmount);
        vm.stopPrank();
    }

    function test_Burn() external {
        uint256 amountToBurn = initialMintAmount / 2;
        uint256 initialTotalSupply = wct.totalSupply();
        uint256 initialMinterBalance = wct.balanceOf(minter);

        // Expect the Transfer event to address(0)
        vm.expectEmit(true, true, true, true, address(wct));
        emit Transfer(minter, address(0), amountToBurn);

        // Perform the burn as the designated minter (Bob)
        vm.startPrank(minter);
        wct.burn(amountToBurn);
        vm.stopPrank();

        // Assert balances and supply
        assertEq(wct.balanceOf(minter), initialMinterBalance - amountToBurn, "Minter balance mismatch after burn");
        assertEq(wct.totalSupply(), initialTotalSupply - amountToBurn, "Total supply mismatch after burn");
    }

    function test_RevertWhen_BurnerIsNotMinter() external {
        address attacker = users.attacker;
        vm.assume(attacker != minter);
        uint256 amountToBurn = 1 ether;

        // Mint some tokens to the attacker first so they have a balance
        vm.startPrank(minter);
        wct.mint(attacker, amountToBurn * 2);
        vm.stopPrank();

        // Attacker tries to burn their own tokens (should fail as they are not the minter)
        vm.startPrank(attacker);
        vm.expectRevert(abi.encodeWithSelector(INttToken.CallerNotMinter.selector, attacker));
        wct.burn(amountToBurn);
        vm.stopPrank();
    }

    function test_RevertWhen_BurnAmountExceedsBalance() external {
        uint256 amountToBurn = initialMintAmount + 1 ether; // More than the minter has

        vm.startPrank(minter);
        // Using ERC20InsufficientBalance selector from OZ ERC20Burnable
        bytes4 expectedError = bytes4(keccak256("ERC20InsufficientBalance(address,uint256,uint256)"));
        vm.expectRevert(abi.encodeWithSelector(expectedError, minter, initialMintAmount, amountToBurn));
        wct.burn(amountToBurn);
        vm.stopPrank();
    }
}
