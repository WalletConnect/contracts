// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import { console2 } from "forge-std/src/console2.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { WalletConnectToken } from "src/WalletConnectToken.sol";

import { Base_Test } from "../../../Base.t.sol";

contract Mint_WalletConnectToken_Unit_Fuzz_Test is Base_Test {
    WalletConnectTokenHarness internal walletConnectTokenHarness;

    function setUp() public override {
        super.setUp();
        walletConnectTokenHarness = new WalletConnectTokenHarness(users.mintManagerOwner);
    }

    function testFuzz_RevertWhen_CallerNotOwner(address attacker) external {
        // // Run the test.
        vm.assume(attacker != address(0) && attacker != users.mintManagerOwner);
        assumeNotPrecompile(attacker);

        // Make the attacker the caller
        vm.startPrank(attacker);

        // Run the test
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, attacker));
        walletConnectToken.mint(attacker, 1);
    }

    modifier whenCallerOwner() {
        vm.startPrank(users.mintManagerOwner);
        _;
    }

    function testFuzz_Mint(address to, uint256 amount) external whenCallerOwner {
        vm.assume(to != address(0));
        amount = bound(amount, 1, walletConnectTokenHarness.maxSupply() - walletConnectTokenHarness.totalSupply() - 1);
        console2.logUint(amount);
        // Get the total supply before minting
        uint256 totalSupply = walletConnectToken.totalSupply();
        // Expect the relevant event to be emitted.
        vm.expectEmit({ emitter: address(walletConnectToken) });
        emit Transfer(address(0), to, amount);

        // Mint {amount} token
        walletConnectToken.mint(to, amount);

        // Assert the token was minted
        assertEq(walletConnectToken.balanceOf(to), amount);
        // Assert the total supply was updated
        assertEq(walletConnectToken.totalSupply(), totalSupply + amount);
    }
}

contract WalletConnectTokenHarness is WalletConnectToken {
    constructor(address owner) WalletConnectToken(owner) { }

    function maxSupply() external view returns (uint256) {
        return _maxSupply();
    }
}
