// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { console2 } from "forge-std/console2.sol";
import { VmSafe } from "forge-std/Vm.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
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

library AirdropJsonHandler {
    using stdJson for string;

    function jsonToMerkleRoot(
        VmSafe vm,
        string memory jsonFilePath
    )
        internal
        view
        returns (bytes32, ClaimWithProof[] memory)
    {
        // Parse the JSON file first to get the array length
        string memory fullPath = string.concat(vm.projectRoot(), jsonFilePath);
        string memory json = vm.readFile(fullPath);
        RawClaimWithProof[] memory rawClaimsWithProof =
            abi.decode(json.parseRaw(".claimsWithProof"), (RawClaimWithProof[]));

        // Pre-allocate the array with the correct size
        ClaimWithProof[] memory claimsWithProof = new ClaimWithProof[](rawClaimsWithProof.length);

        // Fill the array using index assignment
        for (uint256 i = 0; i < rawClaimsWithProof.length; i++) {
            RawClaimWithProof memory rawClaimWithProof = rawClaimsWithProof[i];
            claimsWithProof[i] = ClaimWithProof(
                Claim(
                    bytesToUint(rawClaimWithProof.rawClaim.amount),
                    bytesToUint(rawClaimWithProof.rawClaim.index),
                    rawClaimWithProof.rawClaim.recipient
                ),
                rawClaimWithProof.proof
            );
        }
        return (json.readBytes32(".merkleRoot"), claimsWithProof);
    }
}

function bytesToUint(bytes memory b) pure returns (uint256) {
    require(b.length <= 32, "StdUtils bytesToUint(bytes): Bytes length exceeds 32.");
    return abi.decode(abi.encodePacked(new bytes(32 - b.length), b), (uint256));
}
