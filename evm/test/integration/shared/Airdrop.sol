// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Airdrop } from "src/Airdrop.sol";
import { Integration_Test } from "../Integration.t.sol";
import { AirdropJsonHandler, ClaimWithProof } from "script/utils/AirdropJsonHandler.sol";
import { stdJson } from "forge-std/StdJson.sol";

/// @notice Common logic needed by all integration tests, both concrete and fuzz tests.

abstract contract Airdrop_Test is Integration_Test {
    using stdJson for string;

    ClaimWithProof[] public claimsWithProof;
    Airdrop internal airdrop;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/
    function setUp() public virtual override {
        super.setUp();

        // Disable transfer restrictions.
        vm.prank(address(users.admin));
        l2wct.disableTransferRestrictions();
    }

    function _jsonToMerkleRoot() internal returns (bytes32) {
        // Import the JSON file
        string memory jsonFilePath = "/test/integration/concrete/airdrop/claim/airdrop_data.json";
        (bytes32 merkleRoot, ClaimWithProof[] memory intermediaryClaimsWithProof) =
            AirdropJsonHandler.jsonToMerkleRoot(vm, jsonFilePath);
        for (uint256 i = 0; i < intermediaryClaimsWithProof.length; i++) {
            claimsWithProof.push(intermediaryClaimsWithProof[i]);
        }
        return merkleRoot;
    }

    function _deployAirdrop(bytes32 merkleRoot) internal {
        // Deploy the Airdrop contract.
        airdrop = new Airdrop(
            address(users.admin), address(users.pauser), address(users.treasury), merkleRoot, address(l2wct)
        );

        // Mint tokens to the treasury.
        deal(address(l2wct), address(users.treasury), defaults.AIRDROP_BUDGET());

        // Add prank BEFORE the approval
        vm.startPrank(address(users.treasury));
        // Approve the Airdrop contract to spend WCT.
        l2wct.approve(address(airdrop), defaults.AIRDROP_BUDGET());
        vm.stopPrank();
    }
}
