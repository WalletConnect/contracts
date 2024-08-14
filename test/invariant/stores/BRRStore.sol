// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

contract BRRStore {
    struct Action {
        string actionType;
        address from;
        address to;
        uint256 amount;
    }

    Action[] public actions;
    uint256 public totalMinted;
    uint256 public totalBurned;
    mapping(address => uint256) public userTransfers;
    mapping(address => uint256) public userReceives;
    mapping(address => mapping(address => uint256)) public storedAllowance;
    address[] public addressesWithBalance;
    mapping(address => bool) public hasBalance;

    function addAction(string memory actionType, address from, address to, uint256 amount) public {
        actions.push(Action(actionType, from, to, amount));
        if (keccak256(bytes(actionType)) == keccak256(bytes("mint"))) {
            totalMinted += amount;
        } else if (keccak256(bytes(actionType)) == keccak256(bytes("burn"))) {
            totalBurned += amount;
        }
    }

    function incrementUserTransfers(address user, uint256 amount) public {
        userTransfers[user] += amount;
    }

    function incrementUserReceives(address user, uint256 amount) public {
        userReceives[user] += amount;
    }

    function setStoredAllowance(address owner, address spender, uint256 amount) public {
        storedAllowance[owner][spender] = amount;
    }

    function addAddressWithBalance(address user) public {
        if (!hasBalance[user]) {
            addressesWithBalance.push(user);
            hasBalance[user] = true;
        }
    }

    function removeAddressWithBalance(address user) public {
        if (hasBalance[user]) {
            for (uint256 i = 0; i < addressesWithBalance.length; i++) {
                if (addressesWithBalance[i] == user) {
                    addressesWithBalance[i] = addressesWithBalance[addressesWithBalance.length - 1];
                    addressesWithBalance.pop();
                    break;
                }
            }
            hasBalance[user] = false;
        }
    }

    function getActionsCount() public view returns (uint256) {
        return actions.length;
    }

    function getLatestAction() public view returns (Action memory) {
        require(actions.length > 0, "No actions recorded");
        return actions[actions.length - 1];
    }

    function getAddressesWithBalance() public view returns (address[] memory) {
        return addressesWithBalance;
    }

    function getRandomAddressWithBalance() public view returns (address) {
        require(addressesWithBalance.length > 0, "No addresses with balance");
        return addressesWithBalance[uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender)))
            % addressesWithBalance.length];
    }
}
