// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Invariant_Test } from "./Invariant.t.sol";
import { L2CNKT } from "src/L2CNKT.sol";
import { L2CNKTHandler } from "./handlers/L2CNKTHandler.sol";
import { L2CNKTStore } from "./stores/L2CNKTStore.sol";
import { console2 } from "forge-std/console2.sol";

contract L2CNKT_Invariant_Test is Invariant_Test {
    L2CNKTHandler public handler;
    L2CNKTStore public store;

    function setUp() public override {
        super.setUp();

        // Deploy L2CNKT contract
        store = new L2CNKTStore();
        handler = new L2CNKTHandler(l2cnkt, store, users.admin, users.manager);

        vm.label(address(handler), "L2CNKTHandler");
        vm.label(address(store), "L2CNKTStore");

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
        uint256 totalSupply = l2cnkt.totalSupply();
        uint256 sumOfBalances = 0;
        address[] memory addresses = store.getAddressesWithBalance();
        for (uint256 i = 0; i < addresses.length; i++) {
            sumOfBalances += l2cnkt.balanceOf(addresses[i]);
        }
        assertEq(totalSupply, sumOfBalances, "Total supply should equal sum of balances");
    }

    function invariant_totalSupplyNeverExceedsMaxSupply() public view {
        assertLe(l2cnkt.totalSupply(), CNKT_MAX_SUPPLY, "Total supply should never exceed max supply");
    }

    function invariant_mintsMinusBurnsSumUpToTotalSupply() public view {
        uint256 currentSupply = store.totalMinted() - store.totalBurned();
        assertEq(currentSupply, l2cnkt.totalSupply(), "Current supply should equal total supply");
    }

    function invariant_transferRestrictionsEnforced() public view {
        if (l2cnkt.transferRestrictionsDisabledAfter() > block.timestamp) {
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
            bool isAllowedFrom = l2cnkt.allowedFrom(user);
            bool isAllowedTo = l2cnkt.allowedTo(user);

            if (isAllowedFrom) {
                assertTrue(handler.calls("setAllowedFrom") > 0, "AllowedFrom should be set if true");
            }
            if (isAllowedTo) {
                assertTrue(handler.calls("setAllowedTo") > 0, "AllowedTo should be set if true");
            }
        }
    }

    function invariant_remoteTokenAndBridgeNeverChange() public view {
        assertEq(l2cnkt.REMOTE_TOKEN(), address(cnkt), "Remote token address should not change");
        assertEq(l2cnkt.BRIDGE(), address(mockBridge), "Bridge address should not change");
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
