// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Timelock } from "src/Timelock.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";
import { Integration_Test } from "../Integration.t.sol";

contract SimpleContract {
    uint256 public value;

    function setValue(uint256 newValue) public {
        value = newValue;
    }
}

contract Timelock_Integration_Shared_Test is Integration_Test {
    Timelock public timelock;
    SimpleContract public target;
    address public proposer;
    address public executor;
    bytes public data;
    bytes32 public operationId;
    uint256 public constant TIMELOCK_DELAY = 3 days;
    uint256 public constant OPERATION_VALUE = 0;
    bytes32 public constant OPERATION_SALT = bytes32(0);
    bytes32 public constant OPERATION_PREDECESSOR = bytes32(0);

    function setUp() public override {
        super.setUp();
        address[] memory proposers = new address[](1);
        proposers[0] = users.admin;
        address[] memory executors = new address[](1);
        executors[0] = users.admin;
        proposer = users.admin;
        executor = users.admin;
        timelock = new Timelock(TIMELOCK_DELAY, proposers, executors, users.timelockCanceller);
        target = new SimpleContract();
        data = abi.encodeWithSelector(SimpleContract.setValue.selector, 42);
        operationId =
            timelock.hashOperation(address(target), OPERATION_VALUE, data, OPERATION_PREDECESSOR, OPERATION_SALT);
    }

    function schedule() internal {
        // Schedule operation
        vm.startPrank(proposer);
        timelock.schedule({
            target: address(target),
            value: OPERATION_VALUE,
            data: data,
            predecessor: OPERATION_PREDECESSOR,
            salt: OPERATION_SALT,
            delay: TIMELOCK_DELAY
        });
        vm.stopPrank();
    }

    function __encodeStateBitmap(TimelockController.OperationState state) internal pure returns (bytes32) {
        return bytes32(1 << uint8(state));
    }
}
