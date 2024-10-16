// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Airdrop } from "src/Airdrop.sol";
import { Base_Test } from "test/Base.t.sol";

contract Constructor_Airdrop_Unit_Concrete_Test is Base_Test {
    Airdrop internal airdrop;
    address internal initialAdmin;
    address internal initialPauser;
    address internal reserveAddress;
    bytes32 internal merkleRoot;
    address internal tokenAddress;

    function setUp() public override {
        super.setUp();
        deployCoreConditionally();

        initialAdmin = users.admin;
        initialPauser = users.pauser;
        reserveAddress = users.treasury;
        merkleRoot = keccak256("test");
        tokenAddress = address(l2wct);
    }

    function test_RevertWhen_ReserveAddressIsZero() public {
        vm.expectRevert(Airdrop.InvalidReserveAddress.selector);
        new Airdrop(initialAdmin, initialPauser, address(0), merkleRoot, tokenAddress);
    }

    function test_RevertWhen_TokenAddressIsZero() public {
        vm.expectRevert(Airdrop.InvalidTokenAddress.selector);
        new Airdrop(initialAdmin, initialPauser, reserveAddress, merkleRoot, address(0));
    }

    function test_RevertWhen_MerkleRootIsZero() public {
        vm.expectRevert(Airdrop.InvalidMerkleRoot.selector);
        new Airdrop(initialAdmin, initialPauser, reserveAddress, bytes32(0), tokenAddress);
    }

    function test_Constructor() public {
        airdrop = new Airdrop(initialAdmin, initialPauser, reserveAddress, merkleRoot, tokenAddress);

        assertTrue(airdrop.hasRole(airdrop.DEFAULT_ADMIN_ROLE(), initialAdmin));
        assertTrue(airdrop.hasRole(airdrop.PAUSER_ROLE(), initialPauser));
        assertEq(airdrop.reserveAddress(), reserveAddress);
        assertEq(airdrop.merkleRoot(), merkleRoot);
        assertEq(address(airdrop.token()), tokenAddress);
    }
}
