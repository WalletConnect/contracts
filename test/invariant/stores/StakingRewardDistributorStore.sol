// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

contract StakingRewardDistributorStore {
    struct UserInfo {
        uint256 claimedAmount;
        address setRecipient;
        uint256 lockedAmount;
        uint256 unlockTime;
        bool hasLock;
    }

    mapping(address => UserInfo) public userInfo;
    address[] public users;
    mapping(address => bool) public isUser;
    uint256 public firstLockCreatedAt;
    uint256 public totalFedRewards;
    uint256 public totalInjectedRewards;
    uint256[] public tokensPerWeekInjectedTimestamps;

    function addUser(address user) public {
        if (!isUser[user]) {
            users.push(user);
            isUser[user] = true;
        }
    }

    function getUsers() public view returns (address[] memory) {
        return users;
    }

    function addAddressWithLock(address user) public {
        if (!userInfo[user].hasLock) {
            userInfo[user].hasLock = true;
            addUser(user);
        }
        if (firstLockCreatedAt == 0) {
            firstLockCreatedAt = block.timestamp;
        }
    }

    function removeAddressWithLock(address user) public {
        userInfo[user].hasLock = false;
    }

    function getRandomAddressWithLock() public view returns (address) {
        uint256 lockCount = 0;
        for (uint256 i = 0; i < users.length; i++) {
            if (userInfo[users[i]].hasLock) {
                lockCount++;
            }
        }
        require(lockCount > 0, "No users with lock");

        uint256 randomIndex = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao))) % lockCount;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < users.length; i++) {
            if (userInfo[users[i]].hasLock) {
                if (currentIndex == randomIndex) {
                    return users[i];
                }
                currentIndex++;
            }
        }

        revert("No user found");
    }

    function updateClaimedAmount(address user, uint256 amount) public {
        userInfo[user].claimedAmount += amount;
        addUser(user);
    }

    function setRecipient(address user, address recipient) public {
        userInfo[user].setRecipient = recipient;
        addUser(user);
    }

    function claimedAmount(address user) public view returns (uint256) {
        return userInfo[user].claimedAmount;
    }

    function totalClaimed() public view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < users.length; i++) {
            total += userInfo[users[i]].claimedAmount;
        }
        return total;
    }

    function getSetRecipient(address user) public view returns (address) {
        return userInfo[user].setRecipient;
    }

    function updateLockedAmount(address user, uint256 amount) public {
        userInfo[user].lockedAmount = amount;
        addUser(user);
        if (amount > 0) {
            if (!userInfo[user].hasLock) {
                userInfo[user].hasLock = true;
            }
        } else {
            userInfo[user].hasLock = false;
        }
    }

    function updateUnlockTime(address user, uint256 time) public {
        userInfo[user].unlockTime = time;
        addUser(user);
    }

    function updateTotalInjectedRewards(uint256 amount, uint256 timestamp) public {
        totalInjectedRewards += amount;
        _updateTokensPerWeekInjectedTimestamps(timestamp);
    }

    function updateTotalFedRewards(uint256 amount) public {
        totalFedRewards += amount;
    }

    function getLockedAmount(address user) public view returns (uint256) {
        return userInfo[user].lockedAmount;
    }

    function getUnlockTime(address user) public view returns (uint256) {
        return userInfo[user].unlockTime;
    }

    function getTokensPerWeekInjectedTimestampsLength() public view returns (uint256) {
        return tokensPerWeekInjectedTimestamps.length;
    }

    function _updateTokensPerWeekInjectedTimestamps(uint256 timestamp) internal {
        // check if the timestamp is already in the array
        for (uint256 i = 0; i < tokensPerWeekInjectedTimestamps.length; i++) {
            if (tokensPerWeekInjectedTimestamps[i] == timestamp) {
                return;
            }
        }
        tokensPerWeekInjectedTimestamps.push(timestamp);
    }
}
