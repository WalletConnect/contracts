// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { L2WCT } from "src/L2WCT.sol";
import { INttToken } from "src/interfaces/INttToken.sol";
import { Base_Test } from "../../../../Base.t.sol";
import { IERC20Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

contract Mint_L2WCT_Unit_Concrete_Test is Base_Test {
    uint256 internal constant MINT_AMOUNT = 100;

    function setUp() public override {
        super.setUp();
        deployCoreConditionally();
    }

    function test_RevertWhen_CallerNotMinter() external {
        // Make the attacker the caller
        vm.startPrank(users.attacker);

        // Run the test
        vm.expectRevert(abi.encodeWithSelector(INttToken.CallerNotMinter.selector, users.attacker));
        l2wct.mint(users.attacker, MINT_AMOUNT);
    }

    modifier whenCallerMinter() {
        // Set the caller to the minter
        address currentMinter = l2wct.minter();
        vm.startPrank(currentMinter);
        _;
    }

    function test_MintToNonZeroAddress() external whenCallerMinter {
        // Get initial state
        uint256 initialSupply = l2wct.totalSupply();
        uint256 initialBalance = l2wct.balanceOf(users.alice);

        // Expect the Transfer event to be emitted
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), users.alice, MINT_AMOUNT);

        // Mint tokens
        l2wct.mint(users.alice, MINT_AMOUNT);

        // Assert the token was minted
        assertEq(l2wct.balanceOf(users.alice), initialBalance + MINT_AMOUNT, "Balance should increase");
        assertEq(l2wct.totalSupply(), initialSupply + MINT_AMOUNT, "Total supply should increase");
    }

    function test_MintZeroAmount() external whenCallerMinter {
        // Get initial state
        uint256 initialSupply = l2wct.totalSupply();
        uint256 initialBalance = l2wct.balanceOf(users.alice);

        // Expect the Transfer event to be emitted with 0 amount
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), users.alice, 0);

        // Mint 0 tokens
        l2wct.mint(users.alice, 0);

        // Assert nothing changed
        assertEq(l2wct.balanceOf(users.alice), initialBalance, "Balance should not change");
        assertEq(l2wct.totalSupply(), initialSupply, "Total supply should not change");
    }

    function test_RevertWhen_MintToZeroAddress() external whenCallerMinter {
        // Expect revert when minting to zero address
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        l2wct.mint(address(0), MINT_AMOUNT);
    }
}
