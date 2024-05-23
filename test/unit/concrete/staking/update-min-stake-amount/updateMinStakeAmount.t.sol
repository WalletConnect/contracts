// SPDX-License-Identifier: MIT

import { Staking } from "src/Staking.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Base_Test } from "../../../../Base.t.sol";

pragma solidity >=0.8.25 <0.9.0;

contract UpdateMinStakeAmount_Staking_Unit_Concrete_Test is Base_Test {
    function setUp() public override {
        super.setUp();
        deployCoreConditionally();
    }

    function test_RevertWhen_CallerIsNotOwner() external {
        vm.startPrank(users.attacker);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.attacker));
        staking.updateMinStakeAmount(UINT256_MAX);
    }

    modifier whenCallerIsOwner() {
        vm.startPrank(users.admin);
        _;
    }

    function test_RevertWhen_NewMinStakeAmountIsSameAsOld() external whenCallerIsOwner {
        uint256 oldMinStakeAmount = staking.minStakeAmount();
        vm.expectRevert(Staking.UnchangedState.selector);
        staking.updateMinStakeAmount(oldMinStakeAmount);
    }

    function test_WhenNewMinStakeAmountIsDifferentFromOld() external whenCallerIsOwner {
        uint256 oldMinStakeAmount = staking.minStakeAmount();
        uint256 newMinStakeAmount = oldMinStakeAmount + 1;
        vm.expectEmit({ emitter: address(staking) });
        emit MinStakeAmountUpdated({ oldMinStakeAmount: oldMinStakeAmount, newMinStakeAmount: newMinStakeAmount });
        staking.updateMinStakeAmount(newMinStakeAmount);
        assertEq(staking.minStakeAmount(), newMinStakeAmount);
    }
}
