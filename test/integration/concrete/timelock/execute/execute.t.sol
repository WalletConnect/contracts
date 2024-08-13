// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { Timelock_Integration_Shared_Test } from "test/integration/shared/Timelock.t.sol";

contract Execute_Timelock_Integration_Concrete_Test is Timelock_Integration_Shared_Test {
    function test_RevertWhen_CallerIsNotExecutor() external {
        vm.startPrank(users.attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, users.attacker, timelock.EXECUTOR_ROLE()
            )
        );
        timelock.execute(address(target), OPERATION_VALUE, data, OPERATION_PREDECESSOR, OPERATION_SALT);
        vm.stopPrank();
    }

    modifier whenCallerIsExecutor() {
        vm.startPrank(executor);
        _;
        vm.stopPrank();
    }

    function test_RevertWhen_NoOperationIsScheduled() external whenCallerIsExecutor {
        vm.expectRevert(
            abi.encodeWithSelector(
                TimelockController.TimelockUnexpectedOperationState.selector,
                operationId,
                __encodeStateBitmap(TimelockController.OperationState.Ready)
            )
        );
        timelock.execute(address(target), OPERATION_VALUE, data, OPERATION_PREDECESSOR, OPERATION_SALT);
    }

    modifier givenOperationIsScheduled() {
        schedule();
        _;
    }

    function test_RevertGiven_OperationIsNotReady() external givenOperationIsScheduled whenCallerIsExecutor {
        vm.expectRevert(
            abi.encodeWithSelector(
                TimelockController.TimelockUnexpectedOperationState.selector,
                operationId,
                __encodeStateBitmap(TimelockController.OperationState.Ready)
            )
        );
        timelock.execute(address(target), OPERATION_VALUE, data, OPERATION_PREDECESSOR, OPERATION_SALT);
    }

    modifier givenOperationIsReady() {
        vm.warp(block.timestamp + TIMELOCK_DELAY);
        _;
    }

    function test_Execute() external givenOperationIsScheduled givenOperationIsReady whenCallerIsExecutor {
        uint256 initialValue = target.value();

        // it should emit an {CallExecuted} event
        vm.expectEmit(true, true, true, true);
        emit TimelockController.CallExecuted(operationId, 0, address(target), OPERATION_VALUE, data);

        // it should execute the operation
        timelock.execute(address(target), OPERATION_VALUE, data, OPERATION_PREDECESSOR, OPERATION_SALT);
        assertEq(target.value(), 42);
        assertNotEq(target.value(), initialValue);

        // it should remove the operation from the pending list
        assertFalse(timelock.isOperationPending(operationId));
    }
}
