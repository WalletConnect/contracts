// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25 <0.9.0;

import { BaseHandler } from "./BaseHandler.sol";
import { BRR } from "src/BRR.sol";
import { MintManager } from "src/MintManager.sol";
import { BRRStore } from "../stores/BRRStore.sol";

contract BRRHandler is BaseHandler {
    MintManager public mintManager;
    BRRStore public store;

    constructor(BRR _brr, MintManager _mintManager, BRRStore _store) BaseHandler(_brr) {
        mintManager = _mintManager;
        store = _store;
    }

    function transfer(address from, address to, uint256 amount) public useNewSender(from) instrument("transfer") {
        amount = bound(amount, 0, brr.balanceOf(from));
        brr.transfer(to, amount);
        store.addAction("transfer", from, to, amount);
    }

    function approve(address owner, address spender, uint256 amount) public useNewSender(owner) instrument("approve") {
        brr.approve(spender, amount);
        store.addAction("approve", owner, spender, amount);
    }

    function transferFrom(
        address executor,
        address from,
        address to,
        uint256 amount
    )
        public
        useNewSender(executor)
        instrument("transferFrom")
    {
        amount = bound(amount, 0, brr.allowance(from, executor));
        brr.transferFrom(from, to, amount);
        store.addAction("transferFrom", from, to, amount);
    }

    function mint(address to, uint256 amount) public useNewSender(address(mintManager)) instrument("mint") {
        amount = bound(amount, 0, BRR_MAX_SUPPLY - brr.totalSupply());
        mintManager.mint(to, amount);
        store.addAction("mint", address(0), to, amount);
    }

    function burn(address from, uint256 amount) public useNewSender(from) instrument("burn") {
        amount = bound(amount, 0, brr.balanceOf(from));
        brr.burn(amount);
        store.addAction("burn", from, address(0), amount);
    }
}
