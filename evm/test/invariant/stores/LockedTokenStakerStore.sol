pragma solidity >=0.8.25 <0.9.0;

struct AllocationData {
    address beneficiary;
    bytes decodableArgs;
    bytes32[] proofs;
}

contract LockedTokenStakerStore {
    struct UserInfo {
        int128 currentLockedAmount;
        int128 totalLockedAmount;
        uint256 withdrawnAmount;
        uint256 previousBalance;
        uint256 previousEndTime;
        int128 previousLockedAmount;
        uint256 claimedAmount;
    }

    mapping(address => UserInfo) public userInfo;

    AllocationData[] public allocations;
    mapping(address => bool) public hasAllocation;

    address[] public addressesWithLock;
    mapping(address => bool) public hasLock;
    mapping(address => bool) public hasBeenForcedWithdrawn;
    mapping(address => bool) public hasEverLocked;

    int128 public nonTransferableBalance;
    int128 public currentLockedAmount;
    int128 public totalLockedAmount;
    uint256 public totalWithdrawnAmount;

    function addAddressWithLock(address user) public {
        if (!hasEverLocked[user]) {
            hasEverLocked[user] = true;
        }
        if (!hasLock[user]) {
            addressesWithLock.push(user);
            hasLock[user] = true;
        }
    }

    function removeAddressWithLock(address user) public {
        if (hasLock[user]) {
            for (uint256 i = 0; i < addressesWithLock.length; i++) {
                if (addressesWithLock[i] == user) {
                    addressesWithLock[i] = addressesWithLock[addressesWithLock.length - 1];
                    addressesWithLock.pop();
                    break;
                }
            }
            hasLock[user] = false;
        }
    }

    function getAddressesWithLock() public view returns (address[] memory) {
        return addressesWithLock;
    }

    function getRandomAddressWithLock() public view returns (address) {
        require(addressesWithLock.length > 0, "No addresses with lock");
        return addressesWithLock[uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender)))
            % addressesWithLock.length];
    }

    function addAllocation(AllocationData memory allocation) public {
        if (!hasAllocation[allocation.beneficiary]) {
            allocations.push(allocation);
            hasAllocation[allocation.beneficiary] = true;
        }
    }

    function removeAllocation(address user) public {
        if (hasAllocation[user]) {
            for (uint256 i = 0; i < allocations.length; i++) {
                if (allocations[i].beneficiary == user) {
                    allocations[i] = allocations[allocations.length - 1];
                    allocations.pop();
                    break;
                }
            }
            hasAllocation[user] = false;
        }
    }

    function getAllocations() public view returns (AllocationData[] memory) {
        return allocations;
    }

    function getAllocation(address user) public view returns (AllocationData memory) {
        for (uint256 i = 0; i < allocations.length; i++) {
            if (allocations[i].beneficiary == user) {
                return allocations[i];
            }
        }
        revert("User does not have an allocation");
    }

    function getRandomAllocation(uint256 seed) public view returns (AllocationData memory) {
        require(allocations.length > 0, "No allocations");
        return allocations[uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender, seed)))
            % allocations.length];
    }

    function updateNonTransferableBalance(int128 amount) public {
        nonTransferableBalance += amount;
    }

    function updateLockedAmount(address user, int128 amount) public {
        userInfo[user].previousLockedAmount = userInfo[user].currentLockedAmount;
        userInfo[user].currentLockedAmount += amount;
        currentLockedAmount += amount;
        if (amount > 0) {
            totalLockedAmount += amount;
            userInfo[user].totalLockedAmount += amount;
        }
    }

    function updateWithdrawnAmount(address user, uint256 amount) public {
        totalWithdrawnAmount += amount;
        userInfo[user].withdrawnAmount += amount;
    }

    function updateClaimedAmount(address user, uint256 amount) public {
        userInfo[user].claimedAmount += amount;
    }

    function updatePreviousBalance(address user, uint256 balance) public {
        userInfo[user].previousBalance = balance;
    }

    function updatePreviousEndTime(address user, uint256 endTime) public {
        userInfo[user].previousEndTime = endTime;
    }

    function setHasBeenForcedWithdrawn(address user, bool value) public {
        hasBeenForcedWithdrawn[user] = value;
    }

    function userTotalLockedAmount(address user) public view returns (int128) {
        return userInfo[user].totalLockedAmount;
    }

    function withdrawnAmount(address user) public view returns (uint256) {
        return userInfo[user].withdrawnAmount;
    }

    function getPreviousBalance(address user) public view returns (uint256) {
        return userInfo[user].previousBalance;
    }

    function getPreviousEndTime(address user) public view returns (uint256) {
        return userInfo[user].previousEndTime;
    }

    function getPreviousLockedAmount(address user) public view returns (int128) {
        return userInfo[user].previousLockedAmount;
    }
}
