// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { AirdropHandler } from "./handlers/AirdropHandler.sol";
import { AirdropStore } from "./stores/AirdropStore.sol";
import { Airdrop_Test } from "test/integration/shared/Airdrop.sol";
import { Invariant_Test } from "./Invariant.t.sol";

contract Airdrop_Invariant_Test is Invariant_Test, Airdrop_Test {
    AirdropHandler public handler;
    AirdropStore public store;

    function setUp() public override(Invariant_Test, Airdrop_Test) {
        // Deploy Airdrop contract
        Airdrop_Test.setUp();
        // Load the merkle root and create airdrop from JSON file
        bytes32 merkleRoot = _jsonToMerkleRoot();
        _deployAirdrop(merkleRoot);

        store = new AirdropStore();
        handler = new AirdropHandler(airdrop, store, users.admin, users.pauser, wct, l2wct);

        targetContract(address(handler));

        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = handler.claimTokens.selector;
        selectors[1] = handler.pause.selector;
        selectors[2] = handler.unpause.selector;

        targetSelector(FuzzSelector(address(handler), selectors));
    }

    function invariant_totalClaimedNeverExceedsBudget() public view {
        assertLe(store.totalClaimed(), defaults.AIRDROP_BUDGET(), "Total claimed should never exceed reserve balance");
    }

    function invariant_claimedAmountsNeverDecrease() public view {
        address[] memory claimers = store.getClaimers();
        for (uint256 i = 0; i < claimers.length; i++) {
            address claimer = claimers[i];
            assertGe(l2wct.balanceOf(claimer), store.claims(claimer), "Claimed amount should never decrease");
        }
    }

    function invariant_pausedStateConsistent() public view {
        assertEq(airdrop.paused(), store.paused(), "Paused state should be consistent");
    }

    function invariant_claimOnlyOnce() public view {
        address[] memory claimers = store.getClaimers();
        for (uint256 i = 0; i < claimers.length; i++) {
            address claimer = claimers[i];
            assertTrue(airdrop.claimed(claimer), "Claimer should be marked as claimed");
        }
    }
}
