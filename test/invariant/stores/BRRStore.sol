// SPDX-License-Identifier: UNLICENSED
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

    function addAction(string memory actionType, address from, address to, uint256 amount) public {
        actions.push(Action(actionType, from, to, amount));
        if (keccak256(bytes(actionType)) == keccak256(bytes("mint"))) {
            totalMinted += amount;
        } else if (keccak256(bytes(actionType)) == keccak256(bytes("burn"))) {
            totalBurned += amount;
        }
    }

    function getActionsCount() public view returns (uint256) {
        return actions.length;
    }

    function getLatestAction() public view returns (Action memory) {
        require(actions.length > 0, "No actions recorded");
        return actions[actions.length - 1];
    }
}
