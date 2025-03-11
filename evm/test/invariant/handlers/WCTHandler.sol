// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { BaseHandler } from "./BaseHandler.sol";
import { WCT } from "src/WCT.sol";
import { L2WCT } from "src/L2WCT.sol";
import { WCTStore } from "../stores/WCTStore.sol";

contract WCTHandler is BaseHandler {
    WCTStore public store;

    constructor(WCT _wct, L2WCT _l2wct, WCTStore _store) BaseHandler(_wct, _l2wct) {
        store = _store;
    }

    function transfer(address to, uint256 amount) public instrument("transfer") {
        address from = store.getRandomAddressWithBalance();
        vm.startPrank(from);
        amount = bound(amount, 0, wct.balanceOf(from));
        wct.transfer(to, amount);
        store.addAction("transfer", from, to, amount);
        store.incrementUserTransfers(from, amount);
        store.incrementUserReceives(to, amount);
        store.addAddressWithBalance(to);
        if (wct.balanceOf(from) == 0) {
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
        wct.approve(spender, amount);
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
        amount = bound(amount, 0, wct.allowance(from, executor));
        wct.transferFrom(from, to, amount);
        store.addAction("transferFrom", from, to, amount);
        store.incrementUserTransfers(from, amount);
        store.incrementUserReceives(to, amount);
        store.addAddressWithBalance(to);
        if (wct.balanceOf(from) == 0) {
            store.removeAddressWithBalance(from);
        }
    }

    function mint(address to, uint256 amount) public useNewSender(address(wct.owner())) instrument("mint") {
        amount = bound(amount, 0, WCT_MAX_SUPPLY - wct.totalSupply());
        wct.mint(to, amount);
        store.addAction("mint", address(0), to, amount);
        store.addAddressWithBalance(to);
    }

    function burn(uint256 amount) public instrument("burn") {
        address from = store.getRandomAddressWithBalance();
        vm.startPrank(from);
        amount = bound(amount, 0, wct.balanceOf(from));
        wct.burn(amount);
        store.addAction("burn", from, address(0), amount);
        if (wct.balanceOf(from) == 0) {
            store.removeAddressWithBalance(from);
        }
        vm.stopPrank();
    }
}
