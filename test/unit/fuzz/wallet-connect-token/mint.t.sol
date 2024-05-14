// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import { console2 } from "forge-std/src/console2.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { CNCT } from "src/CNCT.sol";

import { Base_Test } from "../../../Base.t.sol";

contract Mint_CNCT_Unit_Fuzz_Test is Base_Test {
    CNCTHarness internal cnctHarness;

    function setUp() public override {
        super.setUp();
        cnctHarness = new CNCTHarness(users.admin);
    }

    function testFuzz_RevertWhen_CallerNotOwner(address attacker) external {
        // // Run the test.
        vm.assume(attacker != address(0) && attacker != users.admin);
        assumeNotPrecompile(attacker);

        // Make the attacker the caller
        vm.startPrank(attacker);

        // Run the test
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, attacker));
        cnct.mint(attacker, 1);
    }

    modifier whenCallerOwner() {
        vm.startPrank(users.admin);
        _;
    }

    function testFuzz_Mint(address to, uint256 amount) external whenCallerOwner {
        vm.assume(to != address(0));
        amount = bound(amount, 1, cnctHarness.maxSupply() - cnctHarness.totalSupply() - 1);
        console2.logUint(amount);
        // Get the total supply before minting
        uint256 totalSupply = cnct.totalSupply();
        // Expect the relevant event to be emitted.
        vm.expectEmit({ emitter: address(cnct) });
        emit Transfer(address(0), to, amount);

        // Mint {amount} token
        cnct.mint(to, amount);

        // Assert the token was minted
        assertEq(cnct.balanceOf(to), amount);
        // Assert the total supply was updated
        assertEq(cnct.totalSupply(), totalSupply + amount);
    }
}

contract CNCTHarness is CNCT {
    constructor(address owner) CNCT(owner) { }

    function maxSupply() external view returns (uint256) {
        return _maxSupply();
    }
}
