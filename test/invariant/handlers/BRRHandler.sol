// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { BaseHandler } from "./BaseHandler.sol";
import { BRR } from "src/BRR.sol";
import { L2BRR } from "src/L2BRR.sol";
import { BRRStore } from "../stores/BRRStore.sol";

contract BRRHandler is BaseHandler {
    BRRStore public store;

    constructor(BRR _brr, L2BRR _l2brr, BRRStore _store) BaseHandler(_brr, _l2brr) {
        store = _store;
    }

    function transfer(address to, uint256 amount) public instrument("transfer") {
        address from = store.getRandomAddressWithBalance();
        vm.startPrank(from);
        amount = bound(amount, 0, brr.balanceOf(from));
        brr.transfer(to, amount);
        store.addAction("transfer", from, to, amount);
        store.incrementUserTransfers(from, amount);
        store.incrementUserReceives(to, amount);
        store.addAddressWithBalance(to);
        if (brr.balanceOf(from) == 0) {
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
        brr.approve(spender, amount);
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
        amount = bound(amount, 0, brr.allowance(from, executor));
        brr.transferFrom(from, to, amount);
        store.addAction("transferFrom", from, to, amount);
        store.incrementUserTransfers(from, amount);
        store.incrementUserReceives(to, amount);
        store.addAddressWithBalance(to);
        if (brr.balanceOf(from) == 0) {
            store.removeAddressWithBalance(from);
        }
    }

    function mint(address to, uint256 amount) public useNewSender(address(brr.owner())) instrument("mint") {
        amount = bound(amount, 0, BRR_MAX_SUPPLY - brr.totalSupply());
        brr.mint(to, amount);
        store.addAction("mint", address(0), to, amount);
        store.addAddressWithBalance(to);
    }

    function burn(uint256 amount) public instrument("burn") {
        address from = store.getRandomAddressWithBalance();
        vm.startPrank(from);
        amount = bound(amount, 0, brr.balanceOf(from));
        brr.burn(amount);
        store.addAction("burn", from, address(0), amount);
        if (brr.balanceOf(from) == 0) {
            store.removeAddressWithBalance(from);
        }
        vm.stopPrank();
    }
}
