// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import { WalletConnectToken } from "src/WalletConnectToken.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { Base_Test } from "../../../../Base.t.sol";

contract Mint_WalletConnectToken_Unit_Concrete_Test is Base_Test {
    function test_RevertWhen_CallerNotOwner() external {
        // Make the attacker the caller
        vm.startPrank(users.attacker);

        // Run the test
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.attacker));
        walletConnectToken.mint(users.attacker, 1);
    }

    modifier whenCallerOwner() {
        vm.startPrank(users.mintManagerOwner);
        _;
    }

    function test_Mint() external whenCallerOwner {
        // Expect the relevant event to be emitted.
        uint256 totalSupply = walletConnectToken.totalSupply();
        vm.expectEmit({ emitter: address(walletConnectToken) });
        emit Transfer(address(0), users.mintManagerOwner, 1);

        // Mint 1 token
        walletConnectToken.mint(users.mintManagerOwner, 1);

        // Assert the token was minted
        assertEq(walletConnectToken.balanceOf(users.mintManagerOwner), 1);
        // Assert the total supply was updated
        assertEq(walletConnectToken.totalSupply(), totalSupply + 1);
    }
}
