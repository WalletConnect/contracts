// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { UnsafeUpgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { WCT } from "src/WCT.sol";
import { INttToken } from "src/interfaces/INttToken.sol";
import { Base_Test } from "test/Base.t.sol";

contract Mint_WCT_Unit_Concrete_Test is Base_Test {
    address minter;

    function setUp() public override {
        super.setUp();
        deployCoreConditionally();

        minter = users.bob; // Use Bob as the designated minter for tests

        // Set Bob as the minter using the admin account
        vm.prank(users.admin);
        wct.setMinter(minter);
    }

    function test_RevertWhen_CallerNotMinter() external {
        // Use attacker address, which is not the designated minter (Bob)
        address attacker = users.attacker;
        vm.assume(attacker != minter);

        vm.startPrank(attacker);
        vm.expectRevert(abi.encodeWithSelector(INttToken.CallerNotMinter.selector, attacker));
        wct.mint(users.alice, 1 ether);
        vm.stopPrank();
    }

    function test_RevertWhen_NoMinterSet() external {
        // Deploy a fresh WCT instance without setting a minter
        WCT newWct = WCT(
            UnsafeUpgrades.deployTransparentProxy(
                address(new WCT()), users.admin, abi.encodeCall(WCT.initialize, WCT.Init({ initialAdmin: users.admin }))
            )
        );

        // Attempt to mint should fail as minter() defaults to address(0)
        vm.startPrank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(INttToken.CallerNotMinter.selector, users.alice));
        newWct.mint(users.alice, 1 ether);
        vm.stopPrank();
    }

    function test_Mint() external {
        uint256 amountToMint = 500 ether;
        address recipient = users.alice;
        uint256 initialTotalSupply = wct.totalSupply();
        uint256 initialRecipientBalance = wct.balanceOf(recipient);

        // Expect the Transfer event from address(0)
        vm.expectEmit(true, true, true, true, address(wct));
        emit Transfer(address(0), recipient, amountToMint);

        // Perform the mint as the designated minter (Bob)
        vm.startPrank(minter);
        wct.mint(recipient, amountToMint);
        vm.stopPrank();

        // Assert balances and supply
        assertEq(wct.balanceOf(recipient), initialRecipientBalance + amountToMint, "Recipient balance mismatch");
        assertEq(wct.totalSupply(), initialTotalSupply + amountToMint, "Total supply mismatch");
    }
}
