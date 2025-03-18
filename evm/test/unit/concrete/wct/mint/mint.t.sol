// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { WCT } from "src/WCT.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { Base_Test } from "../../../../Base.t.sol";

contract Mint_WCT_Unit_Concrete_Test is Base_Test {
    function setUp() public override {
        super.setUp();
        deployCoreConditionally();
    }

    function test_RevertWhen_CallerNotOwner() external {
        // Make the attacker the caller
        vm.startPrank(users.attacker);

        // Run the test
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.attacker));
        wct.mint(users.attacker, 1);
    }

    modifier whenCallerOwner() {
        vm.startPrank(users.admin);
        _;
    }

    function test_Mint() external whenCallerOwner {
        // Expect the relevant event to be emitted.
        uint256 totalSupply = wct.totalSupply();
        vm.expectEmit({ emitter: address(wct) });
        emit Transfer(address(0), users.admin, 1);

        // Mint 1 token
        wct.mint(users.admin, 1);

        // Assert the token was minted
        assertEq(wct.balanceOf(users.admin), 1);
        // Assert the total supply was updated
        assertEq(wct.totalSupply(), totalSupply + 1);
    }
}
