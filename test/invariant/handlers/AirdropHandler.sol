// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Airdrop } from "src/Airdrop.sol";
import { WCT } from "src/WCT.sol";
import { L2WCT } from "src/L2WCT.sol";
import { AirdropStore } from "../stores/AirdropStore.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { BaseHandler } from "./BaseHandler.sol";

contract AirdropHandler is BaseHandler {
    Airdrop public airdrop;
    AirdropStore public store;
    IERC20 public token;
    address public admin;
    address public pauser;

    constructor(
        Airdrop _airdrop,
        AirdropStore _store,
        address _admin,
        address _pauser,
        WCT _wct,
        L2WCT _l2wct
    )
        BaseHandler(_wct, _l2wct)
    {
        airdrop = _airdrop;
        store = _store;
        token = IERC20(airdrop.token());
        admin = _admin;
        pauser = _pauser;
    }

    function claimTokens(uint256 _index, uint256 _amount, bytes32[] calldata _merkleProof) public {
        address claimer = store.getRandomEligibleClaimer();
        vm.startPrank(claimer);
        try airdrop.claimTokens(_index, _amount, _merkleProof) {
            store.addClaim(claimer, _amount);
        } catch {
            // Claim failed, likely due to invalid proof or already claimed
        }
        vm.stopPrank();
    }

    function pause() public {
        vm.prank(pauser);
        airdrop.pause();
        store.setPaused(true);
    }

    function unpause() public {
        vm.prank(pauser);
        airdrop.unpause();
        store.setPaused(false);
    }
}
