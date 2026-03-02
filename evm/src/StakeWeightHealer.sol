// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { StakeWeight } from "./StakeWeight.sol";

/**
 * @title StakeWeightHealer
 * @notice Minimal contract for healing affected permanent lock users
 *
 * @dev This contract is used in a "sandwich upgrade" pattern:
 *      1. Upgrade proxy to StakeWeightHealer
 *      2. Admin calls batchHealPermanentWeights() to fix affected users
 *      3. Upgrade proxy back to StakeWeight
 *
 * IMPORTANT: This contract accesses the SAME storage slot as StakeWeight
 * via ERC-7201 namespaced storage, reusing StakeWeight.StakeWeightStorage
 * directly. It does NOT inherit from StakeWeight to stay minimal.
 *
 * @author WalletConnect
 */
contract StakeWeightHealer is AccessControlUpgradeable {
    /*//////////////////////////////////////////////////////////////////////////
                                    STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    bytes32 private constant STAKE_WEIGHT_STORAGE_POSITION = keccak256("com.walletconnect.stakeweight.storage");

    function _getStakeWeightStorage() internal pure returns (StakeWeight.StakeWeightStorage storage s) {
        bytes32 position = STAKE_WEIGHT_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    event PermanentWeightHealed(address indexed user, uint256 epoch, uint256 weight);

    /*//////////////////////////////////////////////////////////////////////////
                                HEALING FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * @notice Allows admin to batch heal multiple affected users
     * @param users Array of user addresses to heal
     */
    function batchHealPermanentWeights(address[] calldata users) external onlyRole(DEFAULT_ADMIN_ROLE) {
        StakeWeight.StakeWeightStorage storage s = _getStakeWeightStorage();

        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];

            if (!s.isPermanent[user]) continue;

            uint256 currentWeight = s.permanentStakeWeight[user];
            uint256 userEpoch = s.userPointEpoch[user];

            if (currentWeight > 0 && userEpoch > 0 && s.userPermanentWeightAtEpoch[user][userEpoch] == 0) {
                s.userPermanentWeightAtEpoch[user][userEpoch] = currentWeight;
                emit PermanentWeightHealed(user, userEpoch, currentWeight);
            }
        }
    }
}
