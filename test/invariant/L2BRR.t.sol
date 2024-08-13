// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Invariant_Test } from "./Invariant.t.sol";
import { L2BRR } from "src/L2BRR.sol";
import { L2BRRHandler } from "./handlers/L2BRRHandler.sol";
import { L2BRRStore } from "./stores/L2BRRStore.sol";
import { console2 } from "forge-std/console2.sol";

contract L2BRR_Invariant_Test is Invariant_Test {
    L2BRRHandler public handler;
    L2BRRStore public store;

    function setUp() public override {
        super.setUp();

        // Deploy L2BRR contract
        store = new L2BRRStore();
        handler = new L2BRRHandler(l2brr, store);

        vm.label(address(handler), "L2BRRHandler");
        vm.label(address(store), "L2BRRStore");

        targetContract(address(handler));

        bytes4[] memory selectors = new bytes4[](8);
        selectors[0] = handler.transfer.selector;
        selectors[1] = handler.approve.selector;
        selectors[2] = handler.transferFrom.selector;
        selectors[3] = handler.mint.selector;
        selectors[4] = handler.burn.selector;
        selectors[5] = handler.setAllowedFrom.selector;
        selectors[6] = handler.setAllowedTo.selector;
        selectors[7] = handler.disableTransferRestrictions.selector;

        targetSelector(FuzzSelector(address(handler), selectors));
    }

    function invariant_balanceSum() public view {
        uint256 totalSupply = l2brr.totalSupply();
        uint256 sumOfBalances = 0;
        address[] memory addresses = store.getAddressesWithBalance();
        for (uint256 i = 0; i < addresses.length; i++) {
            sumOfBalances += l2brr.balanceOf(addresses[i]);
        }
        assertEq(totalSupply, sumOfBalances, "Total supply should equal sum of balances");
    }

    function invariant_totalSupplyNeverExceedsMaxSupply() public view {
        assertLe(l2brr.totalSupply(), BRR_MAX_SUPPLY, "Total supply should never exceed max supply");
    }

    function invariant_mintsMinusBurnsSumUpToTotalSupply() public view {
        uint256 currentSupply = store.totalMinted() - store.totalBurned();
        assertEq(currentSupply, l2brr.totalSupply(), "Current supply should equal total supply");
    }

    function invariant_transferRestrictionsEnforced() public view {
        if (l2brr.transferRestrictionsDisabledAfter() > block.timestamp) {
            address[] memory usersWithBalance = store.getAddressesWithBalance();
            for (uint256 i = 0; i < usersWithBalance.length; i++) {
                address user = usersWithBalance[i];

                if (!store.wasAllowedFrom(user)) {
                    assertEq(store.userTransfers(user), 0, "User not allowed from should have no transfers");
                }
                if (!store.wasAllowedTo(user)) {
                    assertEq(store.userReceives(user), 0, "User not allowed to should have no receives");
                }
            }
        }
    }

    function invariant_allowedFromAndToConsistent() public view {
        address[] memory usersWithBalance = store.getAddressesWithBalance();
        for (uint256 i = 0; i < usersWithBalance.length; i++) {
            address user = usersWithBalance[i];
            bool isAllowedFrom = l2brr.allowedFrom(user);
            bool isAllowedTo = l2brr.allowedTo(user);

            if (isAllowedFrom) {
                assertTrue(handler.calls("setAllowedFrom") > 0, "AllowedFrom should be set if true");
            }
            if (isAllowedTo) {
                assertTrue(handler.calls("setAllowedTo") > 0, "AllowedTo should be set if true");
            }
        }
    }

    function invariant_remoteTokenAndBridgeNeverChange() public view {
        assertEq(l2brr.REMOTE_TOKEN(), address(brr), "Remote token address should not change");
        assertEq(l2brr.BRIDGE(), address(mockBridge), "Bridge address should not change");
    }

    function invariant_callSummary() public view {
        console2.log("Total calls:", handler.totalCalls());
        console2.log("Transfer calls:", handler.calls("transfer"));
        console2.log("Approve calls:", handler.calls("approve"));
        console2.log("TransferFrom calls:", handler.calls("transferFrom"));
        console2.log("Mint calls:", handler.calls("mint"));
        console2.log("Burn calls:", handler.calls("burn"));
        console2.log("SetAllowedFrom calls:", handler.calls("setAllowedFrom"));
        console2.log("SetAllowedTo calls:", handler.calls("setAllowedTo"));
        console2.log("Total minted:", store.totalMinted());
        console2.log("Total burned:", store.totalBurned());
        console2.log("Total transfers:", store.userTransfers(address(0)));
        console2.log("Total receives:", store.userReceives(address(0)));
    }
}
