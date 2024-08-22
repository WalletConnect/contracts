// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { BaseHandler } from "./BaseHandler.sol";
import { CNKT } from "src/CNKT.sol";
import { L2CNKT } from "src/L2CNKT.sol";
import { L2CNKTStore } from "../stores/L2CNKTStore.sol";

contract L2CNKTHandler is BaseHandler {
    L2CNKTStore public store;
    address public bridge;
    address public admin;
    address public manager;

    constructor(
        L2CNKT _l2cnkt,
        L2CNKTStore _store,
        address _admin,
        address _manager
    )
        BaseHandler(CNKT(address(0)), _l2cnkt)
    {
        store = _store;
        bridge = l2cnkt.BRIDGE();
        admin = _admin;
        manager = _manager;
    }

    function transfer(address to, uint256 amount) public instrument("transfer") {
        address from = store.getRandomAddressWithBalance();
        vm.startPrank(from);
        amount = bound(amount, 0, l2cnkt.balanceOf(from));
        try l2cnkt.transfer(to, amount) {
            store.addAction("transfer", from, to, amount);
            store.incrementUserTransfers(from, amount);
            store.incrementUserReceives(to, amount);
            store.addAddressWithBalance(to);
            store.addReceivedBy(to, from);
            store.addSentTo(from, to);
            if (l2cnkt.balanceOf(from) == 0) {
                store.removeAddressWithBalance(from);
            }
        } catch {
            // Transfer failed, likely due to restrictions
        }
        vm.stopPrank();
    }

    function approve(
        address tokenOwner,
        address spender,
        uint256 amount
    )
        public
        useNewSender(tokenOwner)
        instrument("approve")
    {
        l2cnkt.approve(spender, amount);
        store.addAction("approve", tokenOwner, spender, amount);
        store.setStoredAllowance(tokenOwner, spender, amount);
    }

    function transferFrom(
        address executor,
        address to,
        uint256 amount
    )
        public
        useNewSender(executor)
        instrument("transferFrom")
    {
        address from = store.getRandomAddressWithBalance();
        amount = bound(amount, 0, l2cnkt.allowance(from, executor));
        try l2cnkt.transferFrom(from, to, amount) {
            store.addAction("transferFrom", from, to, amount);
            store.incrementUserTransfers(from, amount);
            store.incrementUserReceives(to, amount);
            store.addAddressWithBalance(to);
            store.addReceivedBy(to, from);
            if (l2cnkt.balanceOf(from) == 0) {
                store.removeAddressWithBalance(from);
            }
        } catch {
            // TransferFrom failed, likely due to restrictions
        }
    }

    function mint(address to, uint256 amount) public useNewSender(bridge) instrument("mint") {
        (, address msgSender,) = vm.readCallers();
        l2cnkt.mint(to, amount);
        store.addAction("mint", msgSender, to, amount);
        store.addAddressWithBalance(to);
    }

    function burn(uint256 amount) public useNewSender(bridge) instrument("burn") {
        address from = store.getRandomAddressWithBalance();
        (, address msgSender,) = vm.readCallers();
        amount = bound(amount, 0, l2cnkt.balanceOf(from));
        l2cnkt.burn(from, amount);
        store.addAction("burn", from, msgSender, amount);
        if (l2cnkt.balanceOf(from) == 0) {
            store.removeAddressWithBalance(from);
        }
    }

    function setAllowedFrom(
        address account,
        bool isAllowed
    )
        public
        useNewSender(manager)
        instrument("setAllowedFrom")
    {
        l2cnkt.setAllowedFrom(account, isAllowed);
        store.setAllowedFrom(account, isAllowed);
    }

    function setAllowedTo(address account, bool isAllowed) public useNewSender(manager) instrument("setAllowedTo") {
        l2cnkt.setAllowedTo(account, isAllowed);
        store.setAllowedTo(account, isAllowed);
    }

    function disableTransferRestrictions() public useNewSender(admin) instrument("disableTransferRestrictions") {
        l2cnkt.disableTransferRestrictions();
        store.setTransferRestrictionsDisabled(true);
    }
}
