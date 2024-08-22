// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { BaseHandler } from "./BaseHandler.sol";
import { CNKT } from "src/CNKT.sol";
import { L2CNKT } from "src/L2CNKT.sol";
import { CNKTStore } from "../stores/CNKTStore.sol";

contract CNKTHandler is BaseHandler {
    CNKTStore public store;

    constructor(CNKT _cnkt, L2CNKT _l2cnkt, CNKTStore _store) BaseHandler(_cnkt, _l2cnkt) {
        store = _store;
    }

    function transfer(address to, uint256 amount) public instrument("transfer") {
        address from = store.getRandomAddressWithBalance();
        vm.startPrank(from);
        amount = bound(amount, 0, cnkt.balanceOf(from));
        cnkt.transfer(to, amount);
        store.addAction("transfer", from, to, amount);
        store.incrementUserTransfers(from, amount);
        store.incrementUserReceives(to, amount);
        store.addAddressWithBalance(to);
        if (cnkt.balanceOf(from) == 0) {
            store.removeAddressWithBalance(from);
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
        cnkt.approve(spender, amount);
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
        amount = bound(amount, 0, cnkt.allowance(from, executor));
        cnkt.transferFrom(from, to, amount);
        store.addAction("transferFrom", from, to, amount);
        store.incrementUserTransfers(from, amount);
        store.incrementUserReceives(to, amount);
        store.addAddressWithBalance(to);
        if (cnkt.balanceOf(from) == 0) {
            store.removeAddressWithBalance(from);
        }
    }

    function mint(address to, uint256 amount) public useNewSender(address(cnkt.owner())) instrument("mint") {
        amount = bound(amount, 0, CNKT_MAX_SUPPLY - cnkt.totalSupply());
        cnkt.mint(to, amount);
        store.addAction("mint", address(0), to, amount);
        store.addAddressWithBalance(to);
    }

    function burn(uint256 amount) public instrument("burn") {
        address from = store.getRandomAddressWithBalance();
        vm.startPrank(from);
        amount = bound(amount, 0, cnkt.balanceOf(from));
        cnkt.burn(amount);
        store.addAction("burn", from, address(0), amount);
        if (cnkt.balanceOf(from) == 0) {
            store.removeAddressWithBalance(from);
        }
        vm.stopPrank();
    }
}
