// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { L2BRR } from "src/L2BRR.sol";
import { ERC20Votes } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import { Integration_Test } from "test/integration/Integration.t.sol";

contract Mint_L2BRR_Integration_Concrete_Test is Integration_Test {
    function setUp() public override {
        super.setUp();
        deployCoreConditionally();
    }

    function test_RevertWhen_CallerNotBridge() external {
        vm.expectRevert("L2BRR: only bridge can mint and burn");
        vm.prank(users.alice);
        l2brr.mint(users.alice, 100);
    }

    modifier whenCallerBridge() {
        _;
    }

    function test_MintWhenSupplyNotExceedMax() external whenCallerBridge {
        uint256 initialSupply = l2brr.totalSupply();
        uint256 initialBalance = l2brr.balanceOf(users.alice);
        uint256 amount = 100;

        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), users.alice, amount);
        vm.expectEmit(true, true, true, true);
        emit Mint(users.alice, amount);
        vm.expectEmit(true, true, true, true);
        emit ERC20BridgeFinalized(
            address(l2brr), address(brr), users.alice, users.alice, amount, abi.encodePacked(uint32(amount), "")
        );

        vm.startPrank(users.alice);
        mockBridge.bridgeERC20({
            localToken: address(l2brr),
            remoteToken: address(brr),
            amount: amount,
            minGasLimit: uint32(amount),
            extraData: ""
        });
        vm.stopPrank();

        assertEq(l2brr.balanceOf(users.alice), initialBalance + amount, "Balance should increase");
        assertEq(l2brr.totalSupply(), initialSupply + amount, "Total supply should increase");
    }

    function test_RevertWhen_SupplyExceedsMax() external whenCallerBridge {
        uint256 maxSupply = type(uint208).max;
        uint256 currentSupply = l2brr.totalSupply();
        uint256 amountToMint = maxSupply - currentSupply + 1;

        vm.expectRevert(abi.encodeWithSelector(ERC20Votes.ERC20ExceededSafeSupply.selector, amountToMint, maxSupply));
        vm.startPrank(users.alice);
        mockBridge.bridgeERC20({
            localToken: address(l2brr),
            remoteToken: address(brr),
            amount: amountToMint,
            minGasLimit: uint32(amountToMint),
            extraData: ""
        });
        vm.stopPrank();
    }
}
