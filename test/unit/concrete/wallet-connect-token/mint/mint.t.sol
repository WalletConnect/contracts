// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25 <0.9.0;

import { BRR } from "src/BRR.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { Base_Test } from "../../../../Base.t.sol";

contract Mint_BRR_Unit_Concrete_Test is Base_Test {
    function setUp() public override {
        super.setUp();
        deployCoreConditionally();
    }

    function test_RevertWhen_CallerNotOwner() external {
        // Make the attacker the caller
        vm.startPrank(users.attacker);

        // Run the test
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.attacker));
        brr.mint(users.attacker, 1);
    }

    modifier whenCallerOwner() {
        vm.startPrank(users.admin);
        _;
    }

    function test_Mint() external whenCallerOwner {
        // Expect the relevant event to be emitted.
        uint256 totalSupply = brr.totalSupply();
        vm.expectEmit({ emitter: address(brr) });
        emit Transfer(address(0), users.admin, 1);

        // Mint 1 token
        brr.mint(users.admin, 1);

        // Assert the token was minted
        assertEq(brr.balanceOf(users.admin), 1);
        // Assert the total supply was updated
        assertEq(brr.totalSupply(), totalSupply + 1);
    }
}
