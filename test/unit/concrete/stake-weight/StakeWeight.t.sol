// SPDX-License-Identifier: MIT

pragma solidity >=0.8.25 <0.9.0;

import { Base_Test } from "test/Base.t.sol";
import { StakeWeight } from "src/StakeWeight.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract StakeWeight_Concrete_Test is Base_Test {
    StakeWeightHarness stakeWeightHarness;

    function setUp() public virtual override {
        super.setUp();
        deployCoreConditionally();

        StakeWeightHarness implementation = new StakeWeightHarness();

        // Deploy the proxy contract
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(
                StakeWeight.initialize.selector,
                StakeWeight.Init({ admin: users.admin, config: address(walletConnectConfig) })
            )
        );

        // Cast the proxy to StakeWeightHarness
        stakeWeightHarness = StakeWeightHarness(address(proxy));
        // Label the contract
        vm.label({ account: address(stakeWeightHarness), newLabel: "StakeWeightHarness" });
    }
}

contract StakeWeightHarness is StakeWeight {
    function timestampToFloorWeek(uint256 timestamp) external pure returns (uint256) {
        return super._timestampToFloorWeek(timestamp);
    }

    function findUserBlockEpoch(address user, uint256 blockNumber) external view returns (uint256) {
        return super._findUserBlockEpoch(user, blockNumber);
    }

    function findBlockEpoch(uint256 blockNumber, uint256 maxEpoch) external view returns (uint256) {
        return super._findBlockEpoch(blockNumber, maxEpoch);
    }

    function createPointHistory(uint256 blockNumber, uint256 value) external {
        Point memory newPoint =
            Point({ bias: int128(int256(value)), slope: 0, timestamp: block.timestamp, blockNumber: blockNumber });
        pointHistory.push(newPoint);
        epoch += 1;
    }

    function createUserPointHistory(address user, uint256 blockNumber, uint256 value) external {
        Point memory newPoint =
            Point({ bias: int128(int256(value)), slope: 0, timestamp: block.timestamp, blockNumber: blockNumber });
        userPointHistory[user].push(newPoint);
        userPointEpoch[user] += 1;
    }
}
