// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { Timelock } from "src/Timelock.sol";
import { Base_Test } from "test/Base.t.sol";

contract Constructor_Timelock_Unit_Concrete_Test is Base_Test {
    function test_RevertWhen_DelayIsLessThan3Days() external {
        uint256 invalidDelay = 2 days;
        address[] memory proposers = new address[](1);
        proposers[0] = address(1);
        address[] memory executors = new address[](1);
        executors[0] = address(2);
        address canceller = address(3);

        vm.expectRevert(Timelock.InvalidDelay.selector);
        new Timelock(invalidDelay, proposers, executors, canceller);
    }

    function test_RevertWhen_CancellerIsAddressZero() external {
        uint256 delay = 3 days;
        address[] memory proposers = new address[](1);
        proposers[0] = address(1);
        address[] memory executors = new address[](1);
        executors[0] = address(2);
        address canceller = address(0);

        vm.expectRevert(Timelock.InvalidCanceller.selector);
        new Timelock(delay, proposers, executors, canceller);
    }

    function test_RevertWhen_ProposersArrayIsEmpty() external {
        uint256 delay = 3 days;
        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](1);
        executors[0] = address(2);
        address canceller = address(3);

        vm.expectRevert(Timelock.InvalidProposer.selector);
        new Timelock(delay, proposers, executors, canceller);
    }

    function test_RevertWhen_ExecutorsArrayIsEmpty() external {
        uint256 delay = 3 days;
        address[] memory proposers = new address[](1);
        proposers[0] = address(1);
        address[] memory executors = new address[](0);
        address canceller = address(3);

        vm.expectRevert(Timelock.InvalidExecutor.selector);
        new Timelock(delay, proposers, executors, canceller);
    }

    function test_WhenAllParametersAreValid() external {
        uint256 delay = 3 days;
        address[] memory proposers = new address[](1);
        proposers[0] = users.admin;
        address[] memory executors = new address[](1);
        executors[0] = users.admin;
        address canceller = users.timelockCanceller;

        vm.expectEmit(true, true, true, true);
        emit MinDelayChange(0, delay);

        Timelock timelock = new Timelock(delay, proposers, executors, canceller);

        assertEq(timelock.getMinDelay(), delay, "TIMELOCK_DELAY should be set to the provided delay");
        assertTrue(
            timelock.hasRole(timelock.CANCELLER_ROLE(), canceller),
            "CANCELLER_ROLE should be granted to the provided canceller"
        );

        for (uint256 i = 0; i < proposers.length; i++) {
            assertTrue(
                timelock.hasRole(timelock.PROPOSER_ROLE(), proposers[i]),
                "PROPOSER_ROLE should be granted to all provided proposers"
            );
        }

        for (uint256 i = 0; i < executors.length; i++) {
            assertTrue(
                timelock.hasRole(timelock.EXECUTOR_ROLE(), executors[i]),
                "EXECUTOR_ROLE should be granted to all provided executors"
            );
        }
    }
}
