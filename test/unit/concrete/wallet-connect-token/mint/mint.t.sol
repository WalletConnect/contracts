// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import { CNCT } from "src/CNCT.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { Base_Test } from "../../../../Base.t.sol";

contract Mint_CNCT_Unit_Concrete_Test is Base_Test {
    function test_RevertWhen_CallerNotOwner() external {
        // Make the attacker the caller
        vm.startPrank(users.attacker);

        // Run the test
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.attacker));
        cnct.mint(users.attacker, 1);
    }

    modifier whenCallerOwner() {
        vm.startPrank(users.admin);
        _;
    }

    function test_Mint() external whenCallerOwner {
        // Expect the relevant event to be emitted.
        uint256 totalSupply = cnct.totalSupply();
        vm.expectEmit({ emitter: address(cnct) });
        emit Transfer(address(0), users.admin, 1);

        // Mint 1 token
        cnct.mint(users.admin, 1);

        // Assert the token was minted
        assertEq(cnct.balanceOf(users.admin), 1);
        // Assert the total supply was updated
        assertEq(cnct.totalSupply(), totalSupply + 1);
    }
}
