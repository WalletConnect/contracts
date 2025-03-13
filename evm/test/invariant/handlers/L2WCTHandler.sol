// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { BaseHandler } from "./BaseHandler.sol";
import { WCT } from "src/WCT.sol";
import { L2WCT } from "src/L2WCT.sol";
import { L2WCTStore } from "../stores/L2WCTStore.sol";

contract L2WCTHandler is BaseHandler {
    L2WCTStore public store;
    address public minter;
    address public admin;
    address public manager;

    constructor(
        L2WCT _l2wct,
        L2WCTStore _store,
        address _admin,
        address _manager
    )
        BaseHandler(WCT(address(0)), _l2wct)
    {
        store = _store;
        minter = l2wct.minter();
        admin = _admin;
        manager = _manager;
    }

    function transfer(address to, uint256 amount) public instrument("transfer") {
        address from = store.getRandomAddressWithBalance();
        vm.startPrank(from);
        amount = bound(amount, 0, l2wct.balanceOf(from));
        try l2wct.transfer(to, amount) {
            store.addAction("transfer", from, to, amount);
            store.incrementUserTransfers(from, amount);
            store.incrementUserReceives(to, amount);
            store.addAddressWithBalance(to);
            store.addReceivedBy(to, from);
            store.addSentTo(from, to);
            if (l2wct.balanceOf(from) == 0) {
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
        l2wct.approve(spender, amount);
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
        amount = bound(amount, 0, l2wct.allowance(from, executor));
        try l2wct.transferFrom(from, to, amount) {
            store.addAction("transferFrom", from, to, amount);
            store.incrementUserTransfers(from, amount);
            store.incrementUserReceives(to, amount);
            store.addAddressWithBalance(to);
            store.addReceivedBy(to, from);
            if (l2wct.balanceOf(from) == 0) {
                store.removeAddressWithBalance(from);
            }
        } catch {
            // TransferFrom failed, likely due to restrictions
        }
    }

    function mint(address to, uint256 amount) public useNewSender(minter) instrument("mint") {
        (, address msgSender,) = vm.readCallers();
        l2wct.mint(to, amount);
        store.addAction("mint", msgSender, to, amount);
        store.addAddressWithBalance(to);
    }

    function burn(uint256 amount) public useNewSender(minter) instrument("burn") {
        address from = store.getRandomAddressWithBalance();
        (, address msgSender,) = vm.readCallers();
        amount = bound(amount, 0, l2wct.balanceOf(from));
        l2wct.burn(amount);
        store.addAction("burn", from, msgSender, amount);
        if (l2wct.balanceOf(from) == 0) {
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
        l2wct.setAllowedFrom(account, isAllowed);
        store.setAllowedFrom(account, isAllowed);
    }

    function setAllowedTo(address account, bool isAllowed) public useNewSender(manager) instrument("setAllowedTo") {
        l2wct.setAllowedTo(account, isAllowed);
        store.setAllowedTo(account, isAllowed);
    }

    function disableTransferRestrictions() public useNewSender(admin) instrument("disableTransferRestrictions") {
        l2wct.disableTransferRestrictions();
        store.setTransferRestrictionsDisabled(true);
    }
}
