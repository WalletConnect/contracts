// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Invariant_Test } from "./Invariant.t.sol";
import { BRR } from "src/BRR.sol";
import { BRRHandler } from "./handlers/BRRHandler.sol";
import { BRRStore } from "./stores/BRRStore.sol";
import { console2 } from "forge-std/console2.sol";

contract BRR_Invariant_Test is Invariant_Test {
    BRRHandler public handler;
    BRRStore public store;

    function setUp() public override {
        super.setUp();

        store = new BRRStore();
        handler = new BRRHandler(brr, l2brr, store);

        vm.label(address(handler), "BRRHandler");
        vm.label(address(store), "BRRStore");

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
        uint256 totalSupply = brr.totalSupply();
        uint256 sumOfBalances = 0;
        address[] memory addresses = store.getAddressesWithBalance();
        for (uint256 i = 0; i < addresses.length; i++) {
            sumOfBalances += brr.balanceOf(addresses[i]);
        }
        assertEq(totalSupply, sumOfBalances, "Total supply should equal sum of balances");
    }

    function invariant_mintsMinusBurnsSumUpToTotalSupply() public view {
        uint256 currentSupply = store.totalMinted() - store.totalBurned();
        assertEq(currentSupply, brr.totalSupply(), "Current supply should equal total supply");
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
        console2.log("Total transfers:", store.userTransfers(address(0)));
        console2.log("Total receives:", store.userReceives(address(0)));
    }
}
