// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Airdrop } from "src/Airdrop.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { Airdrop_Test, ClaimWithProof } from "test/integration/shared/Airdrop.t.sol";

contract Claim_Airdrop_Integration_Concrete_Test is Airdrop_Test {
    ClaimWithProof internal defaultClaimWithProof;

    function setUp() public override {
        super.setUp();

        // Use the Merkle tree from the JSON file
        _jsonToMerkleRoot();

        defaultClaimWithProof = claimsWithProof[0];
    }

    function test_RevertWhen_Paused() external {
        vm.prank(users.pauser);
        airdrop.pause();

        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        vm.prank(defaultClaimWithProof.claim.recipient);
        airdrop.claimTokens(0, defaultClaimWithProof.claim.amount, defaultClaimWithProof.proof);
    }

    modifier whenNotPaused() {
        _;
    }

    function test_RevertWhen_InvalidAmount() external whenNotPaused {
        bytes32[] memory proof = new bytes32[](0);

        vm.expectRevert(Airdrop.InvalidAmount.selector);
        vm.prank(defaultClaimWithProof.claim.recipient);
        airdrop.claimTokens(0, 0, proof);
    }

    function test_RevertWhen_AlreadyClaimed() external whenNotPaused {
        vm.startPrank(defaultClaimWithProof.claim.recipient);
        airdrop.claimTokens(0, defaultClaimWithProof.claim.amount, defaultClaimWithProof.proof);

        vm.expectRevert(Airdrop.AlreadyClaimed.selector);
        airdrop.claimTokens(0, defaultClaimWithProof.claim.amount, defaultClaimWithProof.proof);
        vm.stopPrank();
    }

    function test_RevertWhen_InvalidProof() external whenNotPaused {
        bytes32[] memory invalidProof = new bytes32[](1);
        invalidProof[0] = bytes32(uint256(1));

        vm.expectRevert(Airdrop.InvalidProof.selector);
        vm.prank(defaultClaimWithProof.claim.recipient);
        airdrop.claimTokens(0, defaultClaimWithProof.claim.amount, invalidProof);
    }

    function test_SuccessfulClaim() external whenNotPaused {
        uint256 initialBalance = l2cnkt.balanceOf(defaultClaimWithProof.claim.recipient);

        vm.expectEmit(true, true, true, true);
        emit TokensClaimed(defaultClaimWithProof.claim.recipient, defaultClaimWithProof.claim.amount);

        vm.prank(defaultClaimWithProof.claim.recipient);
        airdrop.claimTokens(0, defaultClaimWithProof.claim.amount, defaultClaimWithProof.proof);

        assertEq(
            l2cnkt.balanceOf(defaultClaimWithProof.claim.recipient),
            initialBalance + defaultClaimWithProof.claim.amount,
            "Balance should increase"
        );
        assertTrue(airdrop.claimed(defaultClaimWithProof.claim.recipient), "Claim should be marked as completed");
    }

    function test_ClaimAll() external whenNotPaused {
        uint256 totalClaimed;
        uint256 initialTreasuryBalance = l2cnkt.balanceOf(address(users.treasury));

        for (uint256 i = 0; i < claimsWithProof.length; i++) {
            ClaimWithProof memory claimWithProof = claimsWithProof[i];
            uint256 initialBalance = l2cnkt.balanceOf(claimWithProof.claim.recipient);

            vm.prank(claimWithProof.claim.recipient);
            airdrop.claimTokens(claimWithProof.claim.index, claimWithProof.claim.amount, claimWithProof.proof);

            totalClaimed += claimWithProof.claim.amount;

            assertEq(
                l2cnkt.balanceOf(claimWithProof.claim.recipient),
                initialBalance + claimWithProof.claim.amount,
                "Recipient balance should increase by claimed amount"
            );
            assertTrue(airdrop.claimed(claimWithProof.claim.recipient), "Claim should be marked as completed");
        }

        assertEq(defaults.AIRDROP_BUDGET(), totalClaimed, "Total claimed should be equal to the sum of all claims");
        assertEq(
            l2cnkt.balanceOf(address(users.treasury)),
            initialTreasuryBalance - totalClaimed,
            "Treasury balance should decrease by total claimed amount"
        );
        assertEq(l2cnkt.balanceOf(address(airdrop)), 0, "Airdrop contract should have no remaining balance");
    }
}
