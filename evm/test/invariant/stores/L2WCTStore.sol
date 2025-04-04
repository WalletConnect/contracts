// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

contract L2WCTStore {
    struct Action {
        string actionType;
        address from;
        address to;
        uint256 amount;
    }

    Action[] public actions;
    uint256 public totalMinted;
    uint256 public totalBurned;
    bool public transferRestrictionsDisabled;
    mapping(address => uint256) public userTransfers;
    mapping(address => uint256) public userReceives;
    mapping(address => mapping(address => uint256)) public storedAllowance;
    address[] public addressesWithBalance;
    mapping(address => bool) public hasBalance;
    mapping(address => bool) public wasAllowedFrom;
    mapping(address => bool) public wasAllowedTo;
    mapping(address => address[]) public receivedBy;
    mapping(address => address[]) public sentTo;

    function incrementUserTransfers(address user, uint256 amount) public {
        userTransfers[user] += amount;
    }

    function incrementUserReceives(address user, uint256 amount) public {
        userReceives[user] += amount;
    }

    function setStoredAllowance(address owner, address spender, uint256 amount) public {
        storedAllowance[owner][spender] = amount;
    }

    function addAction(string memory actionType, address from, address to, uint256 amount) public {
        actions.push(Action(actionType, from, to, amount));
        bytes32 actionHash = keccak256(bytes(actionType));
        if (actionHash == keccak256(bytes("mint")) || actionHash == keccak256(bytes("crosschainMint"))) {
            totalMinted += amount;
        } else if (actionHash == keccak256(bytes("burn")) || actionHash == keccak256(bytes("crosschainBurn"))) {
            totalBurned += amount;
        }
    }

    function setAllowedFrom(address account, bool isAllowed) public {
        if (isAllowed) {
            wasAllowedFrom[account] = true;
        }
    }

    function setAllowedTo(address account, bool isAllowed) public {
        if (isAllowed) {
            wasAllowedTo[account] = true;
        }
    }

    function setTransferRestrictionsDisabled(bool disabled) public {
        transferRestrictionsDisabled = disabled;
    }

    function getActionsCount() public view returns (uint256) {
        return actions.length;
    }

    function getLatestAction() public view returns (Action memory) {
        require(actions.length > 0, "No actions recorded");
        return actions[actions.length - 1];
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

    function getAddressesWithBalance() public view returns (address[] memory) {
        return addressesWithBalance;
    }

    function getRandomAddressWithBalance() public view returns (address) {
        return addressesWithBalance[uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender)))
            % addressesWithBalance.length];
    }

    function addReceivedBy(address recipient, address sender) public {
        receivedBy[recipient].push(sender);
    }

    function getReceivedBy(address recipient) public view returns (address[] memory) {
        return receivedBy[recipient];
    }

    function addSentTo(address sender, address recipient) public {
        sentTo[sender].push(recipient);
    }

    function getSentTo(address sender) public view returns (address[] memory) {
        return sentTo[sender];
    }
}
