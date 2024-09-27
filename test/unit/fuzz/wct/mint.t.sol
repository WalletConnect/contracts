// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { console2 } from "forge-std/console2.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { WCT } from "src/WCT.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Base_Test } from "../../../Base.t.sol";

contract Mint_WCT_Unit_Fuzz_Test is Base_Test {
    WCTHarness internal wctHarness;

    function setUp() public override {
        super.setUp();
        // Deploy the implementation contract
        WCTHarness implementation = new WCTHarness();

        // Deploy the proxy contract
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(WCT.initialize.selector, WCT.Init({ initialOwner: users.admin }))
        );

        // Cast the proxy to WCTHarness
        wctHarness = WCTHarness(address(proxy));
        // Label the contract
        vm.label({ account: address(wctHarness), newLabel: "WCTHarness" });
    }

    function testFuzz_RevertWhen_CallerNotOwner(address attacker) external {
        vm.assume(attacker != address(0) && attacker != users.admin);
        assumeNotPrecompile(attacker);

        // Make the attacker the caller
        vm.startPrank(attacker);

        // Run the test
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, attacker));
        wctHarness.mint(attacker, 1);
    }

    modifier whenCallerOwner() {
        vm.startPrank(users.admin);
        _;
    }

    function testFuzz_Mint(address to, uint256 amount) external whenCallerOwner {
        vm.assume(to != address(0));
        amount = bound(amount, 1, wctHarness.maxSupply() - wctHarness.totalSupply() - 1);
        console2.logUint(amount);
        // Get the total supply before minting
        uint256 totalSupply = wctHarness.totalSupply();
        // Expect the relevant event to be emitted.
        vm.expectEmit({ emitter: address(wctHarness) });
        emit Transfer(address(0), to, amount);

        // Mint {amount} token
        wctHarness.mint(to, amount);

        // Assert the token was minted
        assertEq(wctHarness.balanceOf(to), amount);
        // Assert the total supply was updated
        assertEq(wctHarness.totalSupply(), totalSupply + amount);
    }
}

contract WCTHarness is WCT {
    function maxSupply() external view returns (uint256) {
        return _maxSupply();
    }
}
