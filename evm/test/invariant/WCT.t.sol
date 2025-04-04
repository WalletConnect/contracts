// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Invariant_Test } from "./Invariant.t.sol";
import { WCTHandler } from "./handlers/WCTHandler.sol";
import { WCTStore } from "./stores/WCTStore.sol";
import { console2 } from "forge-std/console2.sol";

contract WCT_Invariant_Test is Invariant_Test {
    WCTHandler public handler;
    WCTStore public store;

    function setUp() public override {
        super.setUp();

        store = new WCTStore();
        handler = new WCTHandler(wct, l2wct, store);

        vm.label(address(handler), "WCTHandler");
        vm.label(address(store), "WCTStore");

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
        assertLe(wct.totalSupply(), WCT_MAX_SUPPLY, "Total supply should never exceed max supply");
    }

    function invariant_balancesSumUpToTotalSupply() public view {
        uint256 totalSupply = wct.totalSupply();
        uint256 sumOfBalances = 0;
        address[] memory addresses = store.getAddressesWithBalance();
        for (uint256 i = 0; i < addresses.length; i++) {
            sumOfBalances += wct.balanceOf(addresses[i]);
        }
        assertEq(totalSupply, sumOfBalances, "Total supply should equal sum of balances");
    }

    function invariant_mintsMinusBurnsSumUpToTotalSupply() public view {
        uint256 currentSupply = store.totalMinted() - store.totalBurned();
        assertEq(currentSupply, wct.totalSupply(), "Current supply should equal total supply");
    }

    function invariant_callSummary() public view {
        console2.log("--- Call Summary ---");
        console2.log("Total calls:", handler.totalCalls());
        console2.log("Transfer calls:", handler.calls("transfer"));
        console2.log("Approve calls:", handler.calls("approve"));
        console2.log("TransferFrom calls:", handler.calls("transferFrom"));
        console2.log("Mint (NTT) calls:", handler.calls("mint"));
        console2.log("Burn (NTT) calls:", handler.calls("burn"));
        console2.log("--- Store Summary ---");
        console2.log("Total Minted (NTT):", store.totalMinted());
        console2.log("Total Burned (NTT):", store.totalBurned());
    }
}
