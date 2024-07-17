// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { MintManager } from "src/MintManager.sol";
import { BRR } from "src/BRR.sol";
import { Base_Test } from "test/Base.t.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract Upgrade_MintManager_Unit_Concrete_Test is Base_Test {
    MintManager internal mintManager;

    function setUp() public override {
        super.setUp();
        deployCoreConditionally();
        vm.startPrank(users.admin);
        mintManager = new MintManager(users.admin, address(brr));
        brr.transferOwnership(address(mintManager));
        vm.stopPrank();

        vm.label(address(mintManager), "MintManager");
    }

    function test_RevertWhen_CallerIsNotOwner() external {
        vm.startPrank(users.attacker);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.attacker));
        mintManager.upgrade(address(0x1));
        vm.stopPrank();
    }

    modifier whenCallerIsOwner() {
        vm.startPrank(users.admin);
        _;
    }

    function test_RevertWhen_NewMintManagerAddressIsZero() external whenCallerIsOwner {
        vm.expectRevert(MintManager.MintManagerCannotBeEmpty.selector);
        mintManager.upgrade(address(0));
    }

    function test_Upgrade_WhenNewMintManagerAddressIsValid() external whenCallerIsOwner {
        address newMintManagerAddress = address(0x1);

        vm.expectEmit(true, true, true, true);
        emit Ownable.OwnershipTransferred(address(mintManager), newMintManagerAddress);

        mintManager.upgrade(newMintManagerAddress);

        assertEq(brr.owner(), newMintManagerAddress, "Ownership of BRR token should be transferred to new mint manager");
    }
}
