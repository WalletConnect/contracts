pragma solidity >=0.8.25 <0.9.0;

struct AllocationData {
    address beneficiary;
    bytes decodableArgs;
    bytes32[] proofs;
}

contract StakeWeightStore {
    struct UserInfo {
        int128 lockedAmount;
        uint256 withdrawnAmount;
        uint256 previousBalance;
        uint256 previousEndTime;
        int128 previousLockedAmount;
    }

    mapping(address => UserInfo) public userInfo;

    AllocationData[] public allocations;
    mapping(address => bool) public hasAllocation;

    address[] public addressesWithLock;
    mapping(address => bool) public hasLock;

    int128 public totalLockedAmount;
    int128 public nonTransferableBalance;
    uint256 public totalWithdrawnAmount;

    function addAddressWithLock(address user) public {
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

    function getRandomAllocation(uint256 seed) public view returns (AllocationData memory) {
        require(allocations.length > 0, "No allocations");
        return allocations[uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender, seed)))
            % allocations.length];
    }

    function updateNonTransferableBalance(int128 amount) public {
        nonTransferableBalance += amount;
    }

    function updateLockedAmount(address user, int128 amount) public {
        userInfo[user].previousLockedAmount = userInfo[user].lockedAmount;
        totalLockedAmount += amount;
        userInfo[user].lockedAmount += amount;
    }

    function updateWithdrawnAmount(address user, uint256 amount) public {
        totalWithdrawnAmount += amount;
        userInfo[user].withdrawnAmount += amount;
    }

    function updatePreviousBalance(address user, uint256 balance) public {
        userInfo[user].previousBalance = balance;
    }

    function updatePreviousEndTime(address user, uint256 endTime) public {
        userInfo[user].previousEndTime = endTime;
    }

    function lockedAmount(address user) public view returns (int128) {
        return userInfo[user].lockedAmount;
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
