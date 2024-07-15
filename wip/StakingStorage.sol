// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

/// @title Staking Storage Contract
/// @notice Defines the storage layout for the BakersSyndicate staking system
/// @author BakersSyndicate
abstract contract StakingStorage {
    bytes32 internal constant STORAGE_NAMESPACE = keccak256("BakersSyndicate.StakingStorage") - 1;

    struct Stake {
        uint256 amount;
        uint40 lockEndTime;
        uint40 lastRewardCalculationTime;
        uint256 accumulatedRewards;
    }

    struct StakingStorageData {
        IERC20Upgradeable brr;
        mapping(address user => Stake stake) stakes;
        uint256 totalStaked;
        uint256 totalStakeWeight;
        uint256 rewardRate;
        uint40 lastUpdateTime;
        uint256 bMax;
        uint256 bMin;
        uint256 k;
        uint256 p;
    }

    uint256 public constant MIN_LOCK_DURATION = 1 weeks;
    uint256 public constant MAX_LOCK_DURATION = 48 weeks;
    uint256 public constant MAX_BOOST_FACTOR = 4 * 1e18;
    uint256 public constant STAKE_WEIGHT_CAP = 10;

    function _getStorage() internal pure returns (StakingStorageData storage $) {
        assembly {
            $.slot := STORAGE_NAMESPACE
        }
    }

    modifier onlyStakingContract() {
        require(msg.sender == address(this), "Caller is not the staking contract");
        _;
    }
}
