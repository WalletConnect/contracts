// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { ClaimWithProof } from "test/integration/shared/Airdrop.sol";

contract AirdropStore {
    mapping(address => uint256) public claims;
    address[] public claimers;
    ClaimWithProof[] public eligibleClaims;
    uint256 public totalClaimed;
    bool public paused;

    function addClaim(address claimer, uint256 amount) public {
        if (claims[claimer] == 0) {
            claimers.push(claimer);
        }
        claims[claimer] += amount;
        totalClaimed += amount;
    }

    function addEligibleClaims(ClaimWithProof calldata claimWithProof) public {
        eligibleClaims.push(claimWithProof);
    }

    function getRandomEligibleClaimer() public view returns (address) {
        require(eligibleClaims.length > 0, "No eligible claimers");
        ClaimWithProof memory claimWithProof = eligibleClaims[uint256(
            keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender))
        ) % eligibleClaims.length];
        return claimWithProof.claim.recipient;
    }

    function setPaused(bool _paused) public {
        paused = _paused;
    }

    function getClaimers() public view returns (address[] memory) {
        return claimers;
    }
}
