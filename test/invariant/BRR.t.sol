// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Invariant_Test } from "./Invariant.t.sol";
import { BRR } from "src/BRR.sol";
import { MintManager } from "src/MintManager.sol";
import { BRRHandler } from "./handlers/BRRHandler.sol";
import { BRRStore } from "./stores/BRRStore.sol";
import { console2 } from "forge-std/console2.sol";

contract BRR_Invariant_Test is Invariant_Test {
    MintManager public mintManager;
    BRRHandler public handler;
    BRRStore public store;

    function setUp() public override {
        super.setUp();

        mintManager = new MintManager(users.admin, address(brr));
        store = new BRRStore();
        handler = new BRRHandler(brr, l2brr, mintManager, store);

        vm.startPrank(users.admin);
        brr.transferOwnership(address(mintManager));
        vm.stopPrank();

        targetContract(address(handler));

        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = handler.transfer.selector;
        selectors[1] = handler.approve.selector;
        selectors[2] = handler.transferFrom.selector;
        selectors[3] = handler.mint.selector;
        selectors[4] = handler.burn.selector;

        targetSelector(FuzzSelector(address(handler), selectors));
    }

    function invariant_totalSupplyNeverExceedsMaxSupply() public view {
        assertLe(brr.totalSupply(), BRR_MAX_SUPPLY, "Total supply should never exceed max supply");
    }

    function invariant_balancesSumUpToTotalSupply() public view {
        uint256 totalSupplyFromBalances =
            brr.balanceOf(users.bob) + brr.balanceOf(users.alice) + brr.balanceOf(users.admin);
        assertEq(totalSupplyFromBalances, brr.totalSupply(), "Sum of balances should equal total supply");
    }

    function invariant_ownershipNeverChanges() public view {
        assertEq(brr.owner(), address(mintManager), "BRR ownership should always be MintManager");
    }

    function invariant_mintManagerPeriodAlwaysInFuture() public view {
        uint256 mintPermittedAfter = mintManager.mintPermittedAfter();
        if (mintPermittedAfter != 0) {
            assertGe(mintPermittedAfter, block.timestamp, "Mint permitted time should always be in the future");
        }
    }

    function invariant_callSummary() public view {
        console2.log("Total calls:", handler.totalCalls());
        console2.log("Transfer calls:", handler.calls("transfer"));
        console2.log("Approve calls:", handler.calls("approve"));
        console2.log("TransferFrom calls:", handler.calls("transferFrom"));
        console2.log("Mint calls:", handler.calls("mint"));
        console2.log("Burn calls:", handler.calls("burn"));
        console2.log("Total minted:", store.totalMinted());
        console2.log("Total burned:", store.totalBurned());
    }
}
