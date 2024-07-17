// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { MintManager } from "src/MintManager.sol";
import { BRR } from "src/BRR.sol";
import { Integration_Test } from "test/integration/Integration.t.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract Upgrade_MintManager_Integration_Concrete_Test is Integration_Test {
    MintManager internal mintManager;
    MintManager internal newMintManager;

    function setUp() public override {
        super.setUp();
        vm.startPrank(users.admin);
        mintManager = new MintManager(users.admin, address(brr));
        brr.transferOwnership(address(mintManager));
        vm.stopPrank();

        vm.label(address(mintManager), "MintManager");
        vm.label(address(newMintManager), "NewMintManager");
    }

    modifier whenCallerIsOwner() {
        vm.startPrank(users.admin);
        _;
    }

    function test_Integration_AfterSuccessfulUpgrade() external whenCallerIsOwner {
        // Setup new mint manager
        newMintManager = new MintManager(users.admin, address(brr));

        // Perform upgrade
        mintManager.upgrade(address(newMintManager));

        // New mint manager should be able to mint
        newMintManager.mint(users.bob, 100);
        assertEq(brr.balanceOf(users.bob), 100, "New mint manager should be able to mint tokens");
        // Old mint manager should not be able to mint
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(mintManager)));
        mintManager.mint(users.alice, 100);

        assertEq(brr.balanceOf(users.alice), 0, "Old mint manager should not be able to mint tokens");
    }
}
