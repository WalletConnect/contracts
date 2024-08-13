// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { console2 } from "forge-std/console2.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { BRR } from "src/BRR.sol";

import { Base_Test } from "../../../Base.t.sol";

contract Mint_BRR_Unit_Fuzz_Test is Base_Test {
    BRRHarness internal brrHarness;

    function setUp() public override {
        super.setUp();
        brrHarness = new BRRHarness();
        brrHarness.initialize(BRR.Init({ initialOwner: users.admin }));
        // Label the contract
        vm.label({ account: address(brrHarness), newLabel: "BRRHarness" });
    }

    function testFuzz_RevertWhen_CallerNotOwner(address attacker) external {
        vm.assume(attacker != address(0) && attacker != users.admin);
        assumeNotPrecompile(attacker);

        // Make the attacker the caller
        vm.startPrank(attacker);

        // Run the test
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, attacker));
        brrHarness.mint(attacker, 1);
    }

    modifier whenCallerOwner() {
        vm.startPrank(users.admin);
        _;
    }

    function testFuzz_Mint(address to, uint256 amount) external whenCallerOwner {
        vm.assume(to != address(0));
        amount = bound(amount, 1, brrHarness.maxSupply() - brrHarness.totalSupply() - 1);
        console2.logUint(amount);
        // Get the total supply before minting
        uint256 totalSupply = brrHarness.totalSupply();
        // Expect the relevant event to be emitted.
        vm.expectEmit({ emitter: address(brrHarness) });
        emit Transfer(address(0), to, amount);

        // Mint {amount} token
        brrHarness.mint(to, amount);

        // Assert the token was minted
        assertEq(brrHarness.balanceOf(to), amount);
        // Assert the total supply was updated
        assertEq(brrHarness.totalSupply(), totalSupply + amount);
    }
}

contract BRRHarness is BRR {
    function maxSupply() external view returns (uint256) {
        return _maxSupply();
    }
}
