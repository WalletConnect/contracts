// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { L2WCT } from "src/L2WCT.sol";
import { ERC20Votes } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import { Integration_Test } from "test/integration/Integration.t.sol";
import { INttToken } from "src/interfaces/INttToken.sol";

contract Mint_L2WCT_Integration_Concrete_Test is Integration_Test {
    function test_RevertWhen_CallerNotMinter() external {
        vm.expectRevert(abi.encodeWithSelector(INttToken.CallerNotMinter.selector, users.alice));
        vm.prank(users.alice);
        l2wct.mint(users.alice, 100);
    }

    modifier whenCallerMinter() {
        address minterAddress = l2wct.minter();
        vm.startPrank(minterAddress);
        _;
    }

    function test_MintWhenSupplyNotExceedMax() external whenCallerMinter {
        uint256 initialSupply = l2wct.totalSupply();
        uint256 initialBalance = l2wct.balanceOf(users.alice);
        uint256 amount = 100;

        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), users.alice, amount);

        l2wct.mint(users.alice, amount);

        assertEq(l2wct.balanceOf(users.alice), initialBalance + amount, "Balance should increase");
        assertEq(l2wct.totalSupply(), initialSupply + amount, "Total supply should increase");
    }

    function test_RevertWhen_SupplyExceedsMax() external whenCallerMinter {
        uint256 maxSupply = type(uint208).max;
        uint256 currentSupply = l2wct.totalSupply();
        uint256 amountToMint = maxSupply - currentSupply + 1;

        vm.expectRevert(abi.encodeWithSelector(ERC20Votes.ERC20ExceededSafeSupply.selector, maxSupply + 1, maxSupply));
        l2wct.mint(users.alice, amountToMint);
    }
}
