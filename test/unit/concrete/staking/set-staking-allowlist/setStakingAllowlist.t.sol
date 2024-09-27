// SPDX-License-Identifier: MIT

import { Staking } from "src/Staking.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Base_Test } from "../../../../Base.t.sol";

pragma solidity >=0.8.25 <0.9.0;

contract SetStakingAllowlist_Staking_Unit_Concrete_Test is Base_Test {
    function setUp() public override {
        super.setUp();
        deployCoreConditionally();
    }

    function test_RevertWhen_CallerIsNotOwner() external {
        vm.startPrank(users.attacker);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.attacker));
        staking.setStakingAllowlist(true);
    }

    modifier whenCallerIsOwner() {
        vm.startPrank(users.admin);
        _;
    }

    function test_RevertWhen_NewValueIsSameAsOld() external whenCallerIsOwner {
        bool oldIsStakingAllowlist = staking.isStakingAllowlist();
        vm.expectRevert(Staking.UnchangedState.selector);
        staking.setStakingAllowlist(oldIsStakingAllowlist);
    }

    function test_WhenNewValueIsDifferentFromOld() external whenCallerIsOwner {
        bool oldIsStakingAllowlist = staking.isStakingAllowlist();
        bool newIsStakingAllowlist = !oldIsStakingAllowlist;
        vm.expectEmit({ emitter: address(staking) });
        emit StakingAllowlistSet({ isStakingAllowlist: newIsStakingAllowlist });
        staking.setStakingAllowlist(newIsStakingAllowlist);
        assertEq(staking.isStakingAllowlist(), newIsStakingAllowlist);
    }
}
