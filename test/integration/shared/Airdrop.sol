// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Airdrop } from "src/Airdrop.sol";
import { Integration_Test } from "../Integration.t.sol";

import { stdJson } from "forge-std/StdJson.sol";

struct RawClaim {
    bytes amount;
    bytes index;
    address recipient;
}

struct RawClaimWithProof {
    RawClaim rawClaim;
    bytes32[] proof;
}

struct Claim {
    uint256 amount;
    uint256 index;
    address recipient;
}

struct ClaimWithProof {
    Claim claim;
    bytes32[] proof;
}
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

    function _jsonToMerkleRoot() internal {
        // Import the JSON file
        string memory jsonFilePath =
            string.concat(vm.projectRoot(), "/test/integration/concrete/airdrop/claim/airdrop_data.json");
        string memory json = vm.readFile(jsonFilePath);

        // Parse the JSON file
        RawClaimWithProof[] memory rawClaimsWithProof =
            abi.decode(json.parseRaw(".claimsWithProof"), (RawClaimWithProof[]));

        // Parse rawClaimsWithProof to the storage claimsWithProof
        for (uint256 i = 0; i < rawClaimsWithProof.length; i++) {
            RawClaimWithProof memory rawClaimWithProof = rawClaimsWithProof[i];
            ClaimWithProof memory claimWithProof = ClaimWithProof(
                Claim(
                    bytesToUint(rawClaimWithProof.rawClaim.amount),
                    bytesToUint(rawClaimWithProof.rawClaim.index),
                    rawClaimWithProof.rawClaim.recipient
                ),
                rawClaimWithProof.proof
            );
            claimsWithProof.push(claimWithProof);
        }
        bytes32 merkleRoot = json.readBytes32(".merkleRoot");

        _deployAirdrop(merkleRoot);
    }

    function _deployAirdrop(bytes32 merkleRoot) internal {
        // Deploy the Airdrop contract.
        airdrop = new Airdrop(
            address(users.admin), address(users.pauser), address(users.treasury), merkleRoot, address(l2wct)
        );

        // Mint tokens to the treasury.
        vm.startPrank({ msgSender: address(mockBridge) });
        l2wct.mint(address(users.treasury), defaults.AIRDROP_BUDGET());
        resetPrank(users.treasury);
        // Approve the Airdrop contract to spend WCT.
        l2wct.approve(address(airdrop), defaults.AIRDROP_BUDGET());
        vm.stopPrank();
    }
}
