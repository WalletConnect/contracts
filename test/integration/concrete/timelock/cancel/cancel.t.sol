// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25 <0.9.0;

import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { Timelock_Integration_Shared_Test } from "test/integration/shared/Timelock.t.sol";

contract Cancel_Timelock_Integration_Concrete_Test is Timelock_Integration_Shared_Test {
    function test_RevertWhen_CallerIsNotProposerOrCanceller() external {
        vm.startPrank(users.attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, users.attacker, timelock.CANCELLER_ROLE()
            )
        );
        timelock.cancel(operationId);
        vm.stopPrank();
    }

    modifier whenCallerIsCanceller() {
        _;
    }

    function test_RevertGiven_OperationDoesNotExist() external whenCallerIsCanceller {
        bytes32 nonExistentOperationId = keccak256("non-existent-operation");
        bytes32 stateBitmap = __encodeStateBitmap(TimelockController.OperationState.Waiting)
            | __encodeStateBitmap(TimelockController.OperationState.Ready);
        vm.expectRevert(
            abi.encodeWithSelector(
                TimelockController.TimelockUnexpectedOperationState.selector, nonExistentOperationId, stateBitmap
            )
        );
        vm.prank(users.timelockCanceller);
        timelock.cancel(nonExistentOperationId);
    }

    modifier givenOperationExists() {
        schedule();
        _;
    }

    function test_RevertGiven_OperationIsAlreadyExecuted() external givenOperationExists whenCallerIsCanceller {
        vm.warp(block.timestamp + TIMELOCK_DELAY);
        vm.prank(executor);
        timelock.execute(address(target), OPERATION_VALUE, data, OPERATION_PREDECESSOR, OPERATION_SALT);
        vm.expectRevert(
            abi.encodeWithSelector(
                TimelockController.TimelockUnexpectedOperationState.selector,
                operationId,
                __encodeStateBitmap(TimelockController.OperationState.Waiting)
                    | __encodeStateBitmap(TimelockController.OperationState.Ready)
            )
        );
        vm.prank(users.timelockCanceller);
        timelock.cancel(operationId);
    }

    function test_GivenOperationIsPending() external givenOperationExists whenCallerIsCanceller {
        // it should emit a {Cancelled} event
        vm.expectEmit(true, true, true, true);
        emit TimelockController.Cancelled(operationId);

        // it should cancel the operation
        vm.prank(users.timelockCanceller);
        timelock.cancel(operationId);

        // it should remove the operation from the pending list
        assertFalse(timelock.isOperationPending(operationId));
    }
}
