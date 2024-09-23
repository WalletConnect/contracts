// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Invariant_Test } from "./Invariant.t.sol";
import { L2WCTHandler } from "./handlers/L2WCTHandler.sol";
import { L2WCTStore } from "./stores/L2WCTStore.sol";
import { console2 } from "forge-std/console2.sol";

contract L2WCT_Invariant_Test is Invariant_Test {
    L2WCTHandler public handler;
    L2WCTStore public store;

    function setUp() public override {
        super.setUp();

        // Deploy L2WCT contract
        store = new L2WCTStore();
        handler = new L2WCTHandler(l2wct, store, users.admin, users.manager);

        vm.label(address(handler), "L2WCTHandler");
        vm.label(address(store), "L2WCTStore");

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
        uint256 totalSupply = l2wct.totalSupply();
        uint256 sumOfBalances = 0;
        address[] memory addresses = store.getAddressesWithBalance();
        for (uint256 i = 0; i < addresses.length; i++) {
            sumOfBalances += l2wct.balanceOf(addresses[i]);
        }
        assertEq(totalSupply, sumOfBalances, "Total supply should equal sum of balances");
    }

    function invariant_totalSupplyNeverExceedsMaxSupply() public view {
        assertLe(l2wct.totalSupply(), WCT_MAX_SUPPLY, "Total supply should never exceed max supply");
    }

    function invariant_mintsMinusBurnsSumUpToTotalSupply() public view {
        uint256 currentSupply = store.totalMinted() - store.totalBurned();
        assertEq(currentSupply, l2wct.totalSupply(), "Current supply should equal total supply");
    }

    function invariant_transferRestrictionsEnforced() public view {
        if (l2wct.transferRestrictionsDisabledAfter() > block.timestamp) {
            address[] memory usersWithBalance = store.getAddressesWithBalance();
            for (uint256 i = 0; i < usersWithBalance.length; i++) {
                address user = usersWithBalance[i];

                if (!store.wasAllowedFrom(user)) {
                    address[] memory sentTo = store.getSentTo(user);
                    for (uint256 j = 0; j < sentTo.length; j++) {
                        address receiver = sentTo[j];
                        assertTrue(store.wasAllowedTo(receiver), "Receiver should be allowed to");
                    }
                }
                if (!store.wasAllowedTo(user)) {
                    address[] memory receivedBy = store.getReceivedBy(user);
                    for (uint256 j = 0; j < receivedBy.length; j++) {
                        address sender = receivedBy[j];
                        assertTrue(store.wasAllowedFrom(sender), "Sender should be allowed from");
                    }
                }
            }
        }
    }

    function invariant_allowedFromAndToConsistent() public view {
        address[] memory usersWithBalance = store.getAddressesWithBalance();
        for (uint256 i = 0; i < usersWithBalance.length; i++) {
            address user = usersWithBalance[i];
            bool isAllowedFrom = l2wct.allowedFrom(user);
            bool isAllowedTo = l2wct.allowedTo(user);

            if (isAllowedFrom) {
                assertTrue(handler.calls("setAllowedFrom") > 0, "AllowedFrom should be set if true");
            }
            if (isAllowedTo) {
                assertTrue(handler.calls("setAllowedTo") > 0, "AllowedTo should be set if true");
            }
        }
    }

    function invariant_remoteTokenAndBridgeNeverChange() public view {
        assertEq(l2wct.REMOTE_TOKEN(), address(wct), "Remote token address should not change");
        assertEq(l2wct.BRIDGE(), address(mockBridge), "Bridge address should not change");
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
