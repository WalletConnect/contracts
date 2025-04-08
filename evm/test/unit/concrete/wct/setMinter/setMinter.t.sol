// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { WCT } from "src/WCT.sol";
import { Base_Test } from "test/Base.t.sol";

contract SetMinter_WCT_Unit_Concrete_Test is Base_Test {
    function setUp() public override {
        super.setUp();
        deployCoreConditionally();
        // Note: We don't set an initial minter here, as setMinter itself is the function under test.
    }

    function test_SetMinter() external {
        address initialMinter = address(0); // Minter is initially 0
        address newMinter = users.alice;

        vm.startPrank(users.admin); // Only admin can set minter

        vm.expectEmit(true, true, true, true, address(wct));
        emit NewMinter(initialMinter, newMinter);

        wct.setMinter(newMinter);

        assertEq(wct.minter(), newMinter, "New minter was not set correctly");
        vm.stopPrank();
    }

    function test_SetMinter_OverwritesExisting() external {
        address firstMinter = users.bob;
        address secondMinter = users.alice;

        // Set the first minter
        vm.startPrank(users.admin);
        wct.setMinter(firstMinter);
        vm.stopPrank();

        assertEq(wct.minter(), firstMinter, "First minter setup failed");

        // Set the second minter (overwrite)
        vm.startPrank(users.admin);
        vm.expectEmit(true, true, true, true, address(wct));
        emit NewMinter(firstMinter, secondMinter);
        wct.setMinter(secondMinter);
        vm.stopPrank();

        assertEq(wct.minter(), secondMinter, "Overwriting minter failed");
    }

    function test_RevertWhen_SetMinterNotAdmin() external {
        address newMinter = users.alice;
        address nonAdmin = users.attacker;
        vm.assume(nonAdmin != users.admin);

        bytes32 adminRole = wct.DEFAULT_ADMIN_ROLE();

        vm.startPrank(nonAdmin);
        vm.expectRevert(
            abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", nonAdmin, adminRole)
        );
        wct.setMinter(newMinter);
        vm.stopPrank();
    }
}
