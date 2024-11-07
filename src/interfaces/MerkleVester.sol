pragma solidity ^0.8.20 ^0.8.24 ^0.8.4;

// evm/lib/openzeppelin-contracts/contracts/access/IAccessControl.sol

// OpenZeppelin Contracts (last updated v5.0.0) (access/IAccessControl.sol)

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControl {
    /**
     * @dev The `account` is missing a role.
     */
    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

    /**
     * @dev The caller of a function is not the expected one.
     *
     * NOTE: Don't confuse with {AccessControlUnauthorizedAccount}.
     */
    error AccessControlBadConfirmation();

    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     */
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call, an admin role
     * bearer except when using {AccessControl-_setupRole}.
     */
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {AccessControl-_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `callerConfirmation`.
     */
    function renounceRole(bytes32 role, address callerConfirmation) external;
}

// evm/lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/IERC20.sol)

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

// evm/lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/extensions/IERC20Permit.sol)

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 *
 * ==== Security Considerations
 *
 * There are two important considerations concerning the use of `permit`. The first is that a valid permit signature
 * expresses an allowance, and it should not be assumed to convey additional meaning. In particular, it should not be
 * considered as an intention to spend the allowance in any specific way. The second is that because permits have
 * built-in replay protection and can be submitted by anyone, they can be frontrun. A protocol that uses permits should
 * take this into consideration and allow a `permit` call to fail. Combining these two aspects, a pattern that may be
 * generally recommended is:
 *
 * ```solidity
 * function doThingWithPermit(..., uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public {
 *     try token.permit(msg.sender, address(this), value, deadline, v, r, s) {} catch {}
 *     doThing(..., value);
 * }
 *
 * function doThing(..., uint256 value) public {
 *     token.safeTransferFrom(msg.sender, address(this), value);
 *     ...
 * }
 * ```
 *
 * Observe that: 1) `msg.sender` is used as the owner, leaving no ambiguity as to the signer intent, and 2) the use of
 * `try/catch` allows the permit to fail and makes the code tolerant to frontrunning. (See also
 * {SafeERC20-safeTransferFrom}).
 *
 * Additionally, note that smart contract wallets (such as Argent or Safe) are not able to produce permit signatures, so
 * contracts should have entry points that don't rely on permit.
 */
interface IERC20Permit {
    /**
     * @dev Sets `value` as the allowance of `spender` over ``owner``'s tokens,
     * given ``owner``'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-approve} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - the signature must use ``owner``'s current nonce (see {nonces}).
     *
     * For more information on the signature format, see the
     * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     *
     * CAUTION: See Security Considerations above.
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external;

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for {permit}, as defined by {EIP712}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

// evm/lib/openzeppelin-contracts/contracts/utils/Address.sol

// OpenZeppelin Contracts (last updated v5.0.0) (utils/Address.sol)

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev The ETH balance of the account is not enough to perform the operation.
     */
    error AddressInsufficientBalance(address account);

    /**
     * @dev There's no code at `target` (it is not a contract).
     */
    error AddressEmptyCode(address target);

    /**
     * @dev A call to an address target failed. The target may have reverted.
     */
    error FailedInnerCall();

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.8.20/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions
     * pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        if (address(this).balance < amount) {
            revert AddressInsufficientBalance(address(this));
        }

        (bool success,) = recipient.call{ value: amount }("");
        if (!success) {
            revert FailedInnerCall();
        }
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason or custom error, it is bubbled
     * up by this function (like regular Solidity function calls). However, if
     * the call reverted with no returned reason, this function reverts with a
     * {FailedInnerCall} error.
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use
     * https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        if (address(this).balance < value) {
            revert AddressInsufficientBalance(address(this));
        }
        (bool success, bytes memory returndata) = target.call{ value: value }(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and reverts if the target
     * was not a contract or bubbling up the revert reason (falling back to {FailedInnerCall}) in case of an
     * unsuccessful call.
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata
    )
        internal
        view
        returns (bytes memory)
    {
        if (!success) {
            _revert(returndata);
        } else {
            // only check if target is a contract if the call was successful and the return data is empty
            // otherwise we already know that it was a contract
            if (returndata.length == 0 && target.code.length == 0) {
                revert AddressEmptyCode(target);
            }
            return returndata;
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and reverts if it wasn't, either by bubbling the
     * revert reason or with a default {FailedInnerCall} error.
     */
    function verifyCallResult(bool success, bytes memory returndata) internal pure returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            return returndata;
        }
    }

    /**
     * @dev Reverts with returndata if present. Otherwise reverts with {FailedInnerCall}.
     */
    function _revert(bytes memory returndata) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert FailedInnerCall();
        }
    }
}

// evm/lib/openzeppelin-contracts/contracts/utils/Context.sol

// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

// evm/lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol

// OpenZeppelin Contracts (last updated v5.0.0) (utils/ReentrancyGuard.sol)

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    uint256 private _status;

    /**
     * @dev Unauthorized reentrant call.
     */
    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be NOT_ENTERED
        if (_status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }

        // Any calls to nonReentrant after this point will fail
        _status = ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == ENTERED;
    }
}

// evm/lib/openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol

// OpenZeppelin Contracts (last updated v5.0.0) (utils/cryptography/MerkleProof.sol)

/**
 * @dev These functions deal with verification of Merkle Tree proofs.
 *
 * The tree and the proofs can be generated using our
 * https://github.com/OpenZeppelin/merkle-tree[JavaScript library].
 * You will find a quickstart guide in the readme.
 *
 * WARNING: You should avoid using leaf values that are 64 bytes long prior to
 * hashing, or use a hash function other than keccak256 for hashing leaves.
 * This is because the concatenation of a sorted pair of internal nodes in
 * the Merkle tree could be reinterpreted as a leaf value.
 * OpenZeppelin's JavaScript library generates Merkle trees that are safe
 * against this attack out of the box.
 */
library MerkleProof {
    /**
     * @dev The multiproof provided is not valid.
     */
    error MerkleProofInvalidMultiproof();

    /**
     * @dev Returns true if a `leaf` can be proved to be a part of a Merkle tree
     * defined by `root`. For this, a `proof` must be provided, containing
     * sibling hashes on the branch from the leaf to the root of the tree. Each
     * pair of leaves and each pair of pre-images are assumed to be sorted.
     */
    function verify(bytes32[] memory proof, bytes32 root, bytes32 leaf) internal pure returns (bool) {
        return processProof(proof, leaf) == root;
    }

    /**
     * @dev Calldata version of {verify}
     */
    function verifyCalldata(bytes32[] calldata proof, bytes32 root, bytes32 leaf) internal pure returns (bool) {
        return processProofCalldata(proof, leaf) == root;
    }

    /**
     * @dev Returns the rebuilt hash obtained by traversing a Merkle tree up
     * from `leaf` using `proof`. A `proof` is valid if and only if the rebuilt
     * hash matches the root of the tree. When processing the proof, the pairs
     * of leafs & pre-images are assumed to be sorted.
     */
    function processProof(bytes32[] memory proof, bytes32 leaf) internal pure returns (bytes32) {
        bytes32 computedHash = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            computedHash = _hashPair(computedHash, proof[i]);
        }
        return computedHash;
    }

    /**
     * @dev Calldata version of {processProof}
     */
    function processProofCalldata(bytes32[] calldata proof, bytes32 leaf) internal pure returns (bytes32) {
        bytes32 computedHash = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            computedHash = _hashPair(computedHash, proof[i]);
        }
        return computedHash;
    }

    /**
     * @dev Returns true if the `leaves` can be simultaneously proven to be a part of a Merkle tree defined by
     * `root`, according to `proof` and `proofFlags` as described in {processMultiProof}.
     *
     * CAUTION: Not all Merkle trees admit multiproofs. See {processMultiProof} for details.
     */
    function multiProofVerify(
        bytes32[] memory proof,
        bool[] memory proofFlags,
        bytes32 root,
        bytes32[] memory leaves
    )
        internal
        pure
        returns (bool)
    {
        return processMultiProof(proof, proofFlags, leaves) == root;
    }

    /**
     * @dev Calldata version of {multiProofVerify}
     *
     * CAUTION: Not all Merkle trees admit multiproofs. See {processMultiProof} for details.
     */
    function multiProofVerifyCalldata(
        bytes32[] calldata proof,
        bool[] calldata proofFlags,
        bytes32 root,
        bytes32[] memory leaves
    )
        internal
        pure
        returns (bool)
    {
        return processMultiProofCalldata(proof, proofFlags, leaves) == root;
    }

    /**
     * @dev Returns the root of a tree reconstructed from `leaves` and sibling nodes in `proof`. The reconstruction
     * proceeds by incrementally reconstructing all inner nodes by combining a leaf/inner node with either another
     * leaf/inner node or a proof sibling node, depending on whether each `proofFlags` item is true or false
     * respectively.
     *
     * CAUTION: Not all Merkle trees admit multiproofs. To use multiproofs, it is sufficient to ensure that: 1) the tree
     * is complete (but not necessarily perfect), 2) the leaves to be proven are in the opposite order they are in the
     * tree (i.e., as seen from right to left starting at the deepest layer and continuing at the next layer).
     */
    function processMultiProof(
        bytes32[] memory proof,
        bool[] memory proofFlags,
        bytes32[] memory leaves
    )
        internal
        pure
        returns (bytes32 merkleRoot)
    {
        // This function rebuilds the root hash by traversing the tree up from the leaves. The root is rebuilt by
        // consuming and producing values on a queue. The queue starts with the `leaves` array, then goes onto the
        // `hashes` array. At the end of the process, the last hash in the `hashes` array should contain the root of
        // the Merkle tree.
        uint256 leavesLen = leaves.length;
        uint256 proofLen = proof.length;
        uint256 totalHashes = proofFlags.length;

        // Check proof validity.
        if (leavesLen + proofLen != totalHashes + 1) {
            revert MerkleProofInvalidMultiproof();
        }

        // The xxxPos values are "pointers" to the next value to consume in each array. All accesses are done using
        // `xxx[xxxPos++]`, which return the current value and increment the pointer, thus mimicking a queue's "pop".
        bytes32[] memory hashes = new bytes32[](totalHashes);
        uint256 leafPos = 0;
        uint256 hashPos = 0;
        uint256 proofPos = 0;
        // At each step, we compute the next hash using two values:
        // - a value from the "main queue". If not all leaves have been consumed, we get the next leaf, otherwise we
        //   get the next hash.
        // - depending on the flag, either another value from the "main queue" (merging branches) or an element from the
        //   `proof` array.
        for (uint256 i = 0; i < totalHashes; i++) {
            bytes32 a = leafPos < leavesLen ? leaves[leafPos++] : hashes[hashPos++];
            bytes32 b =
                proofFlags[i] ? (leafPos < leavesLen ? leaves[leafPos++] : hashes[hashPos++]) : proof[proofPos++];
            hashes[i] = _hashPair(a, b);
        }

        if (totalHashes > 0) {
            if (proofPos != proofLen) {
                revert MerkleProofInvalidMultiproof();
            }
            unchecked {
                return hashes[totalHashes - 1];
            }
        } else if (leavesLen > 0) {
            return leaves[0];
        } else {
            return proof[0];
        }
    }

    /**
     * @dev Calldata version of {processMultiProof}.
     *
     * CAUTION: Not all Merkle trees admit multiproofs. See {processMultiProof} for details.
     */
    function processMultiProofCalldata(
        bytes32[] calldata proof,
        bool[] calldata proofFlags,
        bytes32[] memory leaves
    )
        internal
        pure
        returns (bytes32 merkleRoot)
    {
        // This function rebuilds the root hash by traversing the tree up from the leaves. The root is rebuilt by
        // consuming and producing values on a queue. The queue starts with the `leaves` array, then goes onto the
        // `hashes` array. At the end of the process, the last hash in the `hashes` array should contain the root of
        // the Merkle tree.
        uint256 leavesLen = leaves.length;
        uint256 proofLen = proof.length;
        uint256 totalHashes = proofFlags.length;

        // Check proof validity.
        if (leavesLen + proofLen != totalHashes + 1) {
            revert MerkleProofInvalidMultiproof();
        }

        // The xxxPos values are "pointers" to the next value to consume in each array. All accesses are done using
        // `xxx[xxxPos++]`, which return the current value and increment the pointer, thus mimicking a queue's "pop".
        bytes32[] memory hashes = new bytes32[](totalHashes);
        uint256 leafPos = 0;
        uint256 hashPos = 0;
        uint256 proofPos = 0;
        // At each step, we compute the next hash using two values:
        // - a value from the "main queue". If not all leaves have been consumed, we get the next leaf, otherwise we
        //   get the next hash.
        // - depending on the flag, either another value from the "main queue" (merging branches) or an element from the
        //   `proof` array.
        for (uint256 i = 0; i < totalHashes; i++) {
            bytes32 a = leafPos < leavesLen ? leaves[leafPos++] : hashes[hashPos++];
            bytes32 b =
                proofFlags[i] ? (leafPos < leavesLen ? leaves[leafPos++] : hashes[hashPos++]) : proof[proofPos++];
            hashes[i] = _hashPair(a, b);
        }

        if (totalHashes > 0) {
            if (proofPos != proofLen) {
                revert MerkleProofInvalidMultiproof();
            }
            unchecked {
                return hashes[totalHashes - 1];
            }
        } else if (leavesLen > 0) {
            return leaves[0];
        } else {
            return proof[0];
        }
    }

    /**
     * @dev Sorts the pair (a, b) and hashes the result.
     */
    function _hashPair(bytes32 a, bytes32 b) private pure returns (bytes32) {
        return a < b ? _efficientHash(a, b) : _efficientHash(b, a);
    }

    /**
     * @dev Implementation of keccak256(abi.encode(a, b)) that doesn't allocate or expand memory.
     */
    function _efficientHash(bytes32 a, bytes32 b) private pure returns (bytes32 value) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            value := keccak256(0x00, 0x40)
        }
    }
}

// evm/lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol

// OpenZeppelin Contracts (last updated v5.0.0) (utils/introspection/IERC165.sol)

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// evm/lib/openzeppelin-contracts/contracts/utils/math/Math.sol

// OpenZeppelin Contracts (last updated v5.0.0) (utils/math/Math.sol)

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    /**
     * @dev Muldiv operation overflow.
     */
    error MathOverflowedMulDiv();

    enum Rounding {
        Floor, // Toward negative infinity
        Ceil, // Toward positive infinity
        Trunc, // Toward zero
        Expand // Away from zero

    }

    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, with an overflow flag.
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds towards infinity instead
     * of rounding towards zero.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        if (b == 0) {
            // Guarantee the same behavior as in a regular Solidity division.
            return a / b;
        }

        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a == 0 ? 0 : (a - 1) / b + 1;
    }

    /**
     * @notice Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or
     * denominator == 0.
     * @dev Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv) with further edits by
     * Uniswap Labs also under MIT license.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
            // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2^256 + prod0.
            uint256 prod0 = x * y; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly {
                let mm := mulmod(x, y, not(0))
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            // Handle non-overflow cases, 256 by 256 division.
            if (prod1 == 0) {
                // Solidity will revert if denominator == 0, unlike the div opcode on its own.
                // The surrounding unchecked block does not change this fact.
                // See https://docs.soliditylang.org/en/latest/control-structures.html#checked-or-unchecked-arithmetic.
                return prod0 / denominator;
            }

            // Make sure the result is less than 2^256. Also prevents denominator == 0.
            if (denominator <= prod1) {
                revert MathOverflowedMulDiv();
            }

            ///////////////////////////////////////////////
            // 512 by 256 division.
            ///////////////////////////////////////////////

            // Make division exact by subtracting the remainder from [prod1 prod0].
            uint256 remainder;
            assembly {
                // Compute remainder using mulmod.
                remainder := mulmod(x, y, denominator)

                // Subtract 256 bit number from 512 bit number.
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            // Factor powers of two out of denominator and compute largest power of two divisor of denominator.
            // Always >= 1. See https://cs.stackexchange.com/q/138556/92363.

            uint256 twos = denominator & (0 - denominator);
            assembly {
                // Divide denominator by twos.
                denominator := div(denominator, twos)

                // Divide [prod1 prod0] by twos.
                prod0 := div(prod0, twos)

                // Flip twos such that it is 2^256 / twos. If twos is zero, then it becomes one.
                twos := add(div(sub(0, twos), twos), 1)
            }

            // Shift in bits from prod1 into prod0.
            prod0 |= prod1 * twos;

            // Invert denominator mod 2^256. Now that denominator is an odd number, it has an inverse modulo 2^256 such
            // that denominator * inv = 1 mod 2^256. Compute the inverse by starting with a seed that is correct for
            // four bits. That is, denominator * inv = 1 mod 2^4.
            uint256 inverse = (3 * denominator) ^ 2;

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also
            // works in modular arithmetic, doubling the correct bits in each step.
            inverse *= 2 - denominator * inverse; // inverse mod 2^8
            inverse *= 2 - denominator * inverse; // inverse mod 2^16
            inverse *= 2 - denominator * inverse; // inverse mod 2^32
            inverse *= 2 - denominator * inverse; // inverse mod 2^64
            inverse *= 2 - denominator * inverse; // inverse mod 2^128
            inverse *= 2 - denominator * inverse; // inverse mod 2^256

            // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
            // This will give us the correct result modulo 2^256. Since the preconditions guarantee that the outcome is
            // less than 2^256, this is the final result. We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inverse;
            return result;
        }
    }

    /**
     * @notice Calculates x * y / denominator with full precision, following the selected rounding direction.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator, Rounding rounding) internal pure returns (uint256) {
        uint256 result = mulDiv(x, y, denominator);
        if (unsignedRoundsUp(rounding) && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
        return result;
    }

    /**
     * @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded
     * towards zero.
     *
     * Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
     */
    function sqrt(uint256 a) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        // For our first guess, we get the biggest power of 2 which is smaller than the square root of the target.
        //
        // We know that the "msb" (most significant bit) of our target number `a` is a power of 2 such that we have
        // `msb(a) <= a < 2*msb(a)`. This value can be written `msb(a)=2**k` with `k=log2(a)`.
        //
        // This can be rewritten `2**log2(a) <= a < 2**(log2(a) + 1)`
        // → `sqrt(2**k) <= sqrt(a) < sqrt(2**(k+1))`
        // → `2**(k/2) <= sqrt(a) < 2**((k+1)/2) <= 2**(k/2 + 1)`
        //
        // Consequently, `2**(log2(a) / 2)` is a good first approximation of `sqrt(a)` with at least 1 correct bit.
        uint256 result = 1 << (log2(a) >> 1);

        // At this point `result` is an estimation with one bit of precision. We know the true value is a uint128,
        // since it is the square root of a uint256. Newton's method converges quadratically (precision doubles at
        // every iteration). We thus need at most 7 iteration to turn our partial result with one bit of precision
        // into the expected uint128 result.
        unchecked {
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            return min(result, a / result);
        }
    }

    /**
     * @notice Calculates sqrt(a), following the selected rounding direction.
     */
    function sqrt(uint256 a, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = sqrt(a);
            return result + (unsignedRoundsUp(rounding) && result * result < a ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 2 of a positive value rounded towards zero.
     * Returns 0 if given 0.
     */
    function log2(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 128;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 64;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 32;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 16;
            }
            if (value >> 8 > 0) {
                value >>= 8;
                result += 8;
            }
            if (value >> 4 > 0) {
                value >>= 4;
                result += 4;
            }
            if (value >> 2 > 0) {
                value >>= 2;
                result += 2;
            }
            if (value >> 1 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 2, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log2(value);
            return result + (unsignedRoundsUp(rounding) && 1 << result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 10 of a positive value rounded towards zero.
     * Returns 0 if given 0.
     */
    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10 ** 64) {
                value /= 10 ** 64;
                result += 64;
            }
            if (value >= 10 ** 32) {
                value /= 10 ** 32;
                result += 32;
            }
            if (value >= 10 ** 16) {
                value /= 10 ** 16;
                result += 16;
            }
            if (value >= 10 ** 8) {
                value /= 10 ** 8;
                result += 8;
            }
            if (value >= 10 ** 4) {
                value /= 10 ** 4;
                result += 4;
            }
            if (value >= 10 ** 2) {
                value /= 10 ** 2;
                result += 2;
            }
            if (value >= 10 ** 1) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log10(value);
            return result + (unsignedRoundsUp(rounding) && 10 ** result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 256 of a positive value rounded towards zero.
     * Returns 0 if given 0.
     *
     * Adding one to the result gives the number of pairs of hex symbols needed to represent `value` as a hex string.
     */
    function log256(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 16;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 8;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 4;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 2;
            }
            if (value >> 8 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 256, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log256(value);
            return result + (unsignedRoundsUp(rounding) && 1 << (result << 3) < value ? 1 : 0);
        }
    }

    /**
     * @dev Returns whether a provided rounding mode is considered rounding up for unsigned integers.
     */
    function unsignedRoundsUp(Rounding rounding) internal pure returns (bool) {
        return uint8(rounding) % 2 == 1;
    }
}

// evm/lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol

// OpenZeppelin Contracts (last updated v5.0.0) (utils/structs/EnumerableSet.sol)
// This file was procedurally generated from scripts/generate/templates/EnumerableSet.js.

/**
 * @dev Library for managing
 * https://en.wikipedia.org/wiki/Set_(abstract_data_type)[sets] of primitive
 * types.
 *
 * Sets have the following properties:
 *
 * - Elements are added, removed, and checked for existence in constant time
 * (O(1)).
 * - Elements are enumerated in O(n). No guarantees are made on the ordering.
 *
 * ```solidity
 * contract Example {
 *     // Add the library methods
 *     using EnumerableSet for EnumerableSet.AddressSet;
 *
 *     // Declare a set state variable
 *     EnumerableSet.AddressSet private mySet;
 * }
 * ```
 *
 * As of v3.3.0, sets of type `bytes32` (`Bytes32Set`), `address` (`AddressSet`)
 * and `uint256` (`UintSet`) are supported.
 *
 * [WARNING]
 * ====
 * Trying to delete such a structure from storage will likely result in data corruption, rendering the structure
 * unusable.
 * See https://github.com/ethereum/solidity/pull/11843[ethereum/solidity#11843] for more info.
 *
 * In order to clean an EnumerableSet, you can either remove all elements one by one or create a fresh instance using an
 * array of EnumerableSet.
 * ====
 */
library EnumerableSet {
    // To implement this library for multiple types with as little code
    // repetition as possible, we write it in terms of a generic Set type with
    // bytes32 values.
    // The Set implementation uses private functions, and user-facing
    // implementations (such as AddressSet) are just wrappers around the
    // underlying Set.
    // This means that we can only create new EnumerableSets for types that fit
    // in bytes32.

    struct Set {
        // Storage of set values
        bytes32[] _values;
        // Position is the index of the value in the `values` array plus 1.
        // Position 0 is used to mean a value is not in the set.
        mapping(bytes32 value => uint256) _positions;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function _add(Set storage set, bytes32 value) private returns (bool) {
        if (!_contains(set, value)) {
            set._values.push(value);
            // The value is stored at length-1, but we add 1 to all indexes
            // and use 0 as a sentinel value
            set._positions[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function _remove(Set storage set, bytes32 value) private returns (bool) {
        // We cache the value's position to prevent multiple reads from the same storage slot
        uint256 position = set._positions[value];

        if (position != 0) {
            // Equivalent to contains(set, value)
            // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
            // the array, and then remove the last element (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

            uint256 valueIndex = position - 1;
            uint256 lastIndex = set._values.length - 1;

            if (valueIndex != lastIndex) {
                bytes32 lastValue = set._values[lastIndex];

                // Move the lastValue to the index where the value to delete is
                set._values[valueIndex] = lastValue;
                // Update the tracked position of the lastValue (that was just moved)
                set._positions[lastValue] = position;
            }

            // Delete the slot where the moved value was stored
            set._values.pop();

            // Delete the tracked position for the deleted slot
            delete set._positions[value];

            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function _contains(Set storage set, bytes32 value) private view returns (bool) {
        return set._positions[value] != 0;
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function _length(Set storage set) private view returns (uint256) {
        return set._values.length;
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function _at(Set storage set, uint256 index) private view returns (bytes32) {
        return set._values[index];
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function _values(Set storage set) private view returns (bytes32[] memory) {
        return set._values;
    }

    // Bytes32Set

    struct Bytes32Set {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _add(set._inner, value);
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _remove(set._inner, value);
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(Bytes32Set storage set, bytes32 value) internal view returns (bool) {
        return _contains(set._inner, value);
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(Bytes32Set storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(Bytes32Set storage set, uint256 index) internal view returns (bytes32) {
        return _at(set._inner, index);
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(Bytes32Set storage set) internal view returns (bytes32[] memory) {
        bytes32[] memory store = _values(set._inner);
        bytes32[] memory result;

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
    }

    // AddressSet

    struct AddressSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(AddressSet storage set, address value) internal returns (bool) {
        return _add(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(AddressSet storage set, address value) internal returns (bool) {
        return _remove(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return _contains(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(AddressSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(AddressSet storage set, uint256 index) internal view returns (address) {
        return address(uint160(uint256(_at(set._inner, index))));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(AddressSet storage set) internal view returns (address[] memory) {
        bytes32[] memory store = _values(set._inner);
        address[] memory result;

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
    }

    // UintSet

    struct UintSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(UintSet storage set, uint256 value) internal returns (bool) {
        return _add(set._inner, bytes32(value));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(UintSet storage set, uint256 value) internal returns (bool) {
        return _remove(set._inner, bytes32(value));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(UintSet storage set, uint256 value) internal view returns (bool) {
        return _contains(set._inner, bytes32(value));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(UintSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(UintSet storage set, uint256 index) internal view returns (uint256) {
        return uint256(_at(set._inner, index));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(UintSet storage set) internal view returns (uint256[] memory) {
        bytes32[] memory store = _values(set._inner);
        uint256[] memory result;

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
    }
}

// evm/lib/solady/src/utils/SafeTransferLib.sol

/// @notice Safe ETH and ERC20 transfer library that gracefully handles missing return values.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/SafeTransferLib.sol)
/// @author Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/SafeTransferLib.sol)
/// @author Permit2 operations from (https://github.com/Uniswap/permit2/blob/main/src/libraries/Permit2Lib.sol)
///
/// @dev Note:
/// - For ETH transfers, please use `forceSafeTransferETH` for DoS protection.
/// - For ERC20s, this implementation won't check that a token has code,
///   responsibility is delegated to the caller.
library SafeTransferLib {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The ETH transfer has failed.
    error ETHTransferFailed();

    /// @dev The ERC20 `transferFrom` has failed.
    error TransferFromFailed();

    /// @dev The ERC20 `transfer` has failed.
    error TransferFailed();

    /// @dev The ERC20 `approve` has failed.
    error ApproveFailed();

    /// @dev The Permit2 operation has failed.
    error Permit2Failed();

    /// @dev The Permit2 amount must be less than `2**160 - 1`.
    error Permit2AmountOverflow();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         CONSTANTS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Suggested gas stipend for contract receiving ETH that disallows any storage writes.
    uint256 internal constant GAS_STIPEND_NO_STORAGE_WRITES = 2300;

    /// @dev Suggested gas stipend for contract receiving ETH to perform a few
    /// storage reads and writes, but low enough to prevent griefing.
    uint256 internal constant GAS_STIPEND_NO_GRIEF = 100_000;

    /// @dev The unique EIP-712 domain domain separator for the DAI token contract.
    bytes32 internal constant DAI_DOMAIN_SEPARATOR = 0xdbb8cf42e1ecb028be3f3dbc922e1d878b963f411dc388ced501601c60f7c6f7;

    /// @dev The address for the WETH9 contract on Ethereum mainnet.
    address internal constant WETH9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /// @dev The canonical Permit2 address.
    /// [Github](https://github.com/Uniswap/permit2)
    /// [Etherscan](https://etherscan.io/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)
    address internal constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       ETH OPERATIONS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // If the ETH transfer MUST succeed with a reasonable gas budget, use the force variants.
    //
    // The regular variants:
    // - Forwards all remaining gas to the target.
    // - Reverts if the target reverts.
    // - Reverts if the current contract has insufficient balance.
    //
    // The force variants:
    // - Forwards with an optional gas stipend
    //   (defaults to `GAS_STIPEND_NO_GRIEF`, which is sufficient for most cases).
    // - If the target reverts, or if the gas stipend is exhausted,
    //   creates a temporary contract to force send the ETH via `SELFDESTRUCT`.
    //   Future compatible with `SENDALL`: https://eips.ethereum.org/EIPS/eip-4758.
    // - Reverts if the current contract has insufficient balance.
    //
    // The try variants:
    // - Forwards with a mandatory gas stipend.
    // - Instead of reverting, returns whether the transfer succeeded.

    /// @dev Sends `amount` (in wei) ETH to `to`.
    function safeTransferETH(address to, uint256 amount) internal {
        /// @solidity memory-safe-assembly
        assembly {
            if iszero(call(gas(), to, amount, codesize(), 0x00, codesize(), 0x00)) {
                mstore(0x00, 0xb12d13eb) // `ETHTransferFailed()`.
                revert(0x1c, 0x04)
            }
        }
    }

    /// @dev Sends all the ETH in the current contract to `to`.
    function safeTransferAllETH(address to) internal {
        /// @solidity memory-safe-assembly
        assembly {
            // Transfer all the ETH and check if it succeeded or not.
            if iszero(call(gas(), to, selfbalance(), codesize(), 0x00, codesize(), 0x00)) {
                mstore(0x00, 0xb12d13eb) // `ETHTransferFailed()`.
                revert(0x1c, 0x04)
            }
        }
    }

    /// @dev Force sends `amount` (in wei) ETH to `to`, with a `gasStipend`.
    function forceSafeTransferETH(address to, uint256 amount, uint256 gasStipend) internal {
        /// @solidity memory-safe-assembly
        assembly {
            if lt(selfbalance(), amount) {
                mstore(0x00, 0xb12d13eb) // `ETHTransferFailed()`.
                revert(0x1c, 0x04)
            }
            if iszero(call(gasStipend, to, amount, codesize(), 0x00, codesize(), 0x00)) {
                mstore(0x00, to) // Store the address in scratch space.
                mstore8(0x0b, 0x73) // Opcode `PUSH20`.
                mstore8(0x20, 0xff) // Opcode `SELFDESTRUCT`.
                if iszero(create(amount, 0x0b, 0x16)) { revert(codesize(), codesize()) } // For gas estimation.
            }
        }
    }

    /// @dev Force sends all the ETH in the current contract to `to`, with a `gasStipend`.
    function forceSafeTransferAllETH(address to, uint256 gasStipend) internal {
        /// @solidity memory-safe-assembly
        assembly {
            if iszero(call(gasStipend, to, selfbalance(), codesize(), 0x00, codesize(), 0x00)) {
                mstore(0x00, to) // Store the address in scratch space.
                mstore8(0x0b, 0x73) // Opcode `PUSH20`.
                mstore8(0x20, 0xff) // Opcode `SELFDESTRUCT`.
                if iszero(create(selfbalance(), 0x0b, 0x16)) { revert(codesize(), codesize()) } // For gas estimation.
            }
        }
    }

    /// @dev Force sends `amount` (in wei) ETH to `to`, with `GAS_STIPEND_NO_GRIEF`.
    function forceSafeTransferETH(address to, uint256 amount) internal {
        /// @solidity memory-safe-assembly
        assembly {
            if lt(selfbalance(), amount) {
                mstore(0x00, 0xb12d13eb) // `ETHTransferFailed()`.
                revert(0x1c, 0x04)
            }
            if iszero(call(GAS_STIPEND_NO_GRIEF, to, amount, codesize(), 0x00, codesize(), 0x00)) {
                mstore(0x00, to) // Store the address in scratch space.
                mstore8(0x0b, 0x73) // Opcode `PUSH20`.
                mstore8(0x20, 0xff) // Opcode `SELFDESTRUCT`.
                if iszero(create(amount, 0x0b, 0x16)) { revert(codesize(), codesize()) } // For gas estimation.
            }
        }
    }

    /// @dev Force sends all the ETH in the current contract to `to`, with `GAS_STIPEND_NO_GRIEF`.
    function forceSafeTransferAllETH(address to) internal {
        /// @solidity memory-safe-assembly
        assembly {
            // forgefmt: disable-next-item
            if iszero(call(GAS_STIPEND_NO_GRIEF, to, selfbalance(), codesize(), 0x00, codesize(), 0x00)) {
                mstore(0x00, to) // Store the address in scratch space.
                mstore8(0x0b, 0x73) // Opcode `PUSH20`.
                mstore8(0x20, 0xff) // Opcode `SELFDESTRUCT`.
                if iszero(create(selfbalance(), 0x0b, 0x16)) { revert(codesize(), codesize()) } // For gas estimation.
            }
        }
    }

    /// @dev Sends `amount` (in wei) ETH to `to`, with a `gasStipend`.
    function trySafeTransferETH(address to, uint256 amount, uint256 gasStipend) internal returns (bool success) {
        /// @solidity memory-safe-assembly
        assembly {
            success := call(gasStipend, to, amount, codesize(), 0x00, codesize(), 0x00)
        }
    }

    /// @dev Sends all the ETH in the current contract to `to`, with a `gasStipend`.
    function trySafeTransferAllETH(address to, uint256 gasStipend) internal returns (bool success) {
        /// @solidity memory-safe-assembly
        assembly {
            success := call(gasStipend, to, selfbalance(), codesize(), 0x00, codesize(), 0x00)
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      ERC20 OPERATIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Sends `amount` of ERC20 `token` from `from` to `to`.
    /// Reverts upon failure.
    ///
    /// The `from` account must have at least `amount` approved for
    /// the current contract to manage.
    function safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Cache the free memory pointer.
            mstore(0x60, amount) // Store the `amount` argument.
            mstore(0x40, to) // Store the `to` argument.
            mstore(0x2c, shl(96, from)) // Store the `from` argument.
            mstore(0x0c, 0x23b872dd000000000000000000000000) // `transferFrom(address,address,uint256)`.
            // Perform the transfer, reverting upon failure.
            if iszero(
                and( // The arguments of `and` are evaluated from right to left.
                    or(eq(mload(0x00), 1), iszero(returndatasize())), // Returned 1 or nothing.
                    call(gas(), token, 0, 0x1c, 0x64, 0x00, 0x20)
                )
            ) {
                mstore(0x00, 0x7939f424) // `TransferFromFailed()`.
                revert(0x1c, 0x04)
            }
            mstore(0x60, 0) // Restore the zero slot to zero.
            mstore(0x40, m) // Restore the free memory pointer.
        }
    }

    /// @dev Sends `amount` of ERC20 `token` from `from` to `to`.
    ///
    /// The `from` account must have at least `amount` approved for the current contract to manage.
    function trySafeTransferFrom(
        address token,
        address from,
        address to,
        uint256 amount
    )
        internal
        returns (bool success)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Cache the free memory pointer.
            mstore(0x60, amount) // Store the `amount` argument.
            mstore(0x40, to) // Store the `to` argument.
            mstore(0x2c, shl(96, from)) // Store the `from` argument.
            mstore(0x0c, 0x23b872dd000000000000000000000000) // `transferFrom(address,address,uint256)`.
            success :=
                and( // The arguments of `and` are evaluated from right to left.
                    or(eq(mload(0x00), 1), iszero(returndatasize())), // Returned 1 or nothing.
                    call(gas(), token, 0, 0x1c, 0x64, 0x00, 0x20)
                )
            mstore(0x60, 0) // Restore the zero slot to zero.
            mstore(0x40, m) // Restore the free memory pointer.
        }
    }

    /// @dev Sends all of ERC20 `token` from `from` to `to`.
    /// Reverts upon failure.
    ///
    /// The `from` account must have their entire balance approved for the current contract to manage.
    function safeTransferAllFrom(address token, address from, address to) internal returns (uint256 amount) {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Cache the free memory pointer.
            mstore(0x40, to) // Store the `to` argument.
            mstore(0x2c, shl(96, from)) // Store the `from` argument.
            mstore(0x0c, 0x70a08231000000000000000000000000) // `balanceOf(address)`.
            // Read the balance, reverting upon failure.
            if iszero(
                and( // The arguments of `and` are evaluated from right to left.
                    gt(returndatasize(), 0x1f), // At least 32 bytes returned.
                    staticcall(gas(), token, 0x1c, 0x24, 0x60, 0x20)
                )
            ) {
                mstore(0x00, 0x7939f424) // `TransferFromFailed()`.
                revert(0x1c, 0x04)
            }
            mstore(0x00, 0x23b872dd) // `transferFrom(address,address,uint256)`.
            amount := mload(0x60) // The `amount` is already at 0x60. We'll need to return it.
            // Perform the transfer, reverting upon failure.
            if iszero(
                and( // The arguments of `and` are evaluated from right to left.
                    or(eq(mload(0x00), 1), iszero(returndatasize())), // Returned 1 or nothing.
                    call(gas(), token, 0, 0x1c, 0x64, 0x00, 0x20)
                )
            ) {
                mstore(0x00, 0x7939f424) // `TransferFromFailed()`.
                revert(0x1c, 0x04)
            }
            mstore(0x60, 0) // Restore the zero slot to zero.
            mstore(0x40, m) // Restore the free memory pointer.
        }
    }

    /// @dev Sends `amount` of ERC20 `token` from the current contract to `to`.
    /// Reverts upon failure.
    function safeTransfer(address token, address to, uint256 amount) internal {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x14, to) // Store the `to` argument.
            mstore(0x34, amount) // Store the `amount` argument.
            mstore(0x00, 0xa9059cbb000000000000000000000000) // `transfer(address,uint256)`.
            // Perform the transfer, reverting upon failure.
            if iszero(
                and( // The arguments of `and` are evaluated from right to left.
                    or(eq(mload(0x00), 1), iszero(returndatasize())), // Returned 1 or nothing.
                    call(gas(), token, 0, 0x10, 0x44, 0x00, 0x20)
                )
            ) {
                mstore(0x00, 0x90b8ec18) // `TransferFailed()`.
                revert(0x1c, 0x04)
            }
            mstore(0x34, 0) // Restore the part of the free memory pointer that was overwritten.
        }
    }

    /// @dev Sends all of ERC20 `token` from the current contract to `to`.
    /// Reverts upon failure.
    function safeTransferAll(address token, address to) internal returns (uint256 amount) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, 0x70a08231) // Store the function selector of `balanceOf(address)`.
            mstore(0x20, address()) // Store the address of the current contract.
            // Read the balance, reverting upon failure.
            if iszero(
                and( // The arguments of `and` are evaluated from right to left.
                    gt(returndatasize(), 0x1f), // At least 32 bytes returned.
                    staticcall(gas(), token, 0x1c, 0x24, 0x34, 0x20)
                )
            ) {
                mstore(0x00, 0x90b8ec18) // `TransferFailed()`.
                revert(0x1c, 0x04)
            }
            mstore(0x14, to) // Store the `to` argument.
            amount := mload(0x34) // The `amount` is already at 0x34. We'll need to return it.
            mstore(0x00, 0xa9059cbb000000000000000000000000) // `transfer(address,uint256)`.
            // Perform the transfer, reverting upon failure.
            if iszero(
                and( // The arguments of `and` are evaluated from right to left.
                    or(eq(mload(0x00), 1), iszero(returndatasize())), // Returned 1 or nothing.
                    call(gas(), token, 0, 0x10, 0x44, 0x00, 0x20)
                )
            ) {
                mstore(0x00, 0x90b8ec18) // `TransferFailed()`.
                revert(0x1c, 0x04)
            }
            mstore(0x34, 0) // Restore the part of the free memory pointer that was overwritten.
        }
    }

    /// @dev Sets `amount` of ERC20 `token` for `to` to manage on behalf of the current contract.
    /// Reverts upon failure.
    function safeApprove(address token, address to, uint256 amount) internal {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x14, to) // Store the `to` argument.
            mstore(0x34, amount) // Store the `amount` argument.
            mstore(0x00, 0x095ea7b3000000000000000000000000) // `approve(address,uint256)`.
            // Perform the approval, reverting upon failure.
            if iszero(
                and( // The arguments of `and` are evaluated from right to left.
                    or(eq(mload(0x00), 1), iszero(returndatasize())), // Returned 1 or nothing.
                    call(gas(), token, 0, 0x10, 0x44, 0x00, 0x20)
                )
            ) {
                mstore(0x00, 0x3e3f8f73) // `ApproveFailed()`.
                revert(0x1c, 0x04)
            }
            mstore(0x34, 0) // Restore the part of the free memory pointer that was overwritten.
        }
    }

    /// @dev Sets `amount` of ERC20 `token` for `to` to manage on behalf of the current contract.
    /// If the initial attempt to approve fails, attempts to reset the approved amount to zero,
    /// then retries the approval again (some tokens, e.g. USDT, requires this).
    /// Reverts upon failure.
    function safeApproveWithRetry(address token, address to, uint256 amount) internal {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x14, to) // Store the `to` argument.
            mstore(0x34, amount) // Store the `amount` argument.
            mstore(0x00, 0x095ea7b3000000000000000000000000) // `approve(address,uint256)`.
            // Perform the approval, retrying upon failure.
            if iszero(
                and( // The arguments of `and` are evaluated from right to left.
                    or(eq(mload(0x00), 1), iszero(returndatasize())), // Returned 1 or nothing.
                    call(gas(), token, 0, 0x10, 0x44, 0x00, 0x20)
                )
            ) {
                mstore(0x34, 0) // Store 0 for the `amount`.
                mstore(0x00, 0x095ea7b3000000000000000000000000) // `approve(address,uint256)`.
                pop(call(gas(), token, 0, 0x10, 0x44, codesize(), 0x00)) // Reset the approval.
                mstore(0x34, amount) // Store back the original `amount`.
                // Retry the approval, reverting upon failure.
                if iszero(
                    and(
                        or(eq(mload(0x00), 1), iszero(returndatasize())), // Returned 1 or nothing.
                        call(gas(), token, 0, 0x10, 0x44, 0x00, 0x20)
                    )
                ) {
                    mstore(0x00, 0x3e3f8f73) // `ApproveFailed()`.
                    revert(0x1c, 0x04)
                }
            }
            mstore(0x34, 0) // Restore the part of the free memory pointer that was overwritten.
        }
    }

    /// @dev Returns the amount of ERC20 `token` owned by `account`.
    /// Returns zero if the `token` does not exist.
    function balanceOf(address token, address account) internal view returns (uint256 amount) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x14, account) // Store the `account` argument.
            mstore(0x00, 0x70a08231000000000000000000000000) // `balanceOf(address)`.
            amount :=
                mul( // The arguments of `mul` are evaluated from right to left.
                    mload(0x20),
                    and( // The arguments of `and` are evaluated from right to left.
                        gt(returndatasize(), 0x1f), // At least 32 bytes returned.
                        staticcall(gas(), token, 0x10, 0x24, 0x20, 0x20)
                    )
                )
        }
    }

    /// @dev Sends `amount` of ERC20 `token` from `from` to `to`.
    /// If the initial attempt fails, try to use Permit2 to transfer the token.
    /// Reverts upon failure.
    ///
    /// The `from` account must have at least `amount` approved for the current contract to manage.
    function safeTransferFrom2(address token, address from, address to, uint256 amount) internal {
        if (!trySafeTransferFrom(token, from, to, amount)) {
            permit2TransferFrom(token, from, to, amount);
        }
    }

    /// @dev Sends `amount` of ERC20 `token` from `from` to `to` via Permit2.
    /// Reverts upon failure.
    function permit2TransferFrom(address token, address from, address to, uint256 amount) internal {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            mstore(add(m, 0x74), shr(96, shl(96, token)))
            mstore(add(m, 0x54), amount)
            mstore(add(m, 0x34), to)
            mstore(add(m, 0x20), shl(96, from))
            // `transferFrom(address,address,uint160,address)`.
            mstore(m, 0x36c78516000000000000000000000000)
            let p := PERMIT2
            let exists := eq(chainid(), 1)
            if iszero(exists) { exists := iszero(iszero(extcodesize(p))) }
            if iszero(and(call(gas(), p, 0, add(m, 0x10), 0x84, codesize(), 0x00), exists)) {
                mstore(0x00, 0x7939f4248757f0fd) // `TransferFromFailed()` or `Permit2AmountOverflow()`.
                revert(add(0x18, shl(2, iszero(iszero(shr(160, amount))))), 0x04)
            }
        }
    }

    /// @dev Permit a user to spend a given amount of
    /// another user's tokens via native EIP-2612 permit if possible, falling
    /// back to Permit2 if native permit fails or is not implemented on the token.
    function permit2(
        address token,
        address owner,
        address spender,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        internal
    {
        bool success;
        /// @solidity memory-safe-assembly
        assembly {
            for { } shl(96, xor(token, WETH9)) { } {
                mstore(0x00, 0x3644e515) // `DOMAIN_SEPARATOR()`.
                if iszero(
                    and( // The arguments of `and` are evaluated from right to left.
                        lt(iszero(mload(0x00)), eq(returndatasize(), 0x20)), // Returns 1 non-zero word.
                        // Gas stipend to limit gas burn for tokens that don't refund gas when
                        // an non-existing function is called. 5K should be enough for a SLOAD.
                        staticcall(5000, token, 0x1c, 0x04, 0x00, 0x20)
                    )
                ) { break }
                // After here, we can be sure that token is a contract.
                let m := mload(0x40)
                mstore(add(m, 0x34), spender)
                mstore(add(m, 0x20), shl(96, owner))
                mstore(add(m, 0x74), deadline)
                if eq(mload(0x00), DAI_DOMAIN_SEPARATOR) {
                    mstore(0x14, owner)
                    mstore(0x00, 0x7ecebe00000000000000000000000000) // `nonces(address)`.
                    mstore(add(m, 0x94), staticcall(gas(), token, 0x10, 0x24, add(m, 0x54), 0x20))
                    mstore(m, 0x8fcbaf0c000000000000000000000000) // `IDAIPermit.permit`.
                    // `nonces` is already at `add(m, 0x54)`.
                    // `1` is already stored at `add(m, 0x94)`.
                    mstore(add(m, 0xb4), and(0xff, v))
                    mstore(add(m, 0xd4), r)
                    mstore(add(m, 0xf4), s)
                    success := call(gas(), token, 0, add(m, 0x10), 0x104, codesize(), 0x00)
                    break
                }
                mstore(m, 0xd505accf000000000000000000000000) // `IERC20Permit.permit`.
                mstore(add(m, 0x54), amount)
                mstore(add(m, 0x94), and(0xff, v))
                mstore(add(m, 0xb4), r)
                mstore(add(m, 0xd4), s)
                success := call(gas(), token, 0, add(m, 0x10), 0xe4, codesize(), 0x00)
                break
            }
        }
        if (!success) simplePermit2(token, owner, spender, amount, deadline, v, r, s);
    }

    /// @dev Simple permit on the Permit2 contract.
    function simplePermit2(
        address token,
        address owner,
        address spender,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        internal
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            mstore(m, 0x927da105) // `allowance(address,address,address)`.
            {
                let addressMask := shr(96, not(0))
                mstore(add(m, 0x20), and(addressMask, owner))
                mstore(add(m, 0x40), and(addressMask, token))
                mstore(add(m, 0x60), and(addressMask, spender))
                mstore(add(m, 0xc0), and(addressMask, spender))
            }
            let p := mul(PERMIT2, iszero(shr(160, amount)))
            if iszero(
                and( // The arguments of `and` are evaluated from right to left.
                    gt(returndatasize(), 0x5f), // Returns 3 words: `amount`, `expiration`, `nonce`.
                    staticcall(gas(), p, add(m, 0x1c), 0x64, add(m, 0x60), 0x60)
                )
            ) {
                mstore(0x00, 0x6b836e6b8757f0fd) // `Permit2Failed()` or `Permit2AmountOverflow()`.
                revert(add(0x18, shl(2, iszero(p))), 0x04)
            }
            mstore(m, 0x2b67b570) // `Permit2.permit` (PermitSingle variant).
            // `owner` is already `add(m, 0x20)`.
            // `token` is already at `add(m, 0x40)`.
            mstore(add(m, 0x60), amount)
            mstore(add(m, 0x80), 0xffffffffffff) // `expiration = type(uint48).max`.
            // `nonce` is already at `add(m, 0xa0)`.
            // `spender` is already at `add(m, 0xc0)`.
            mstore(add(m, 0xe0), deadline)
            mstore(add(m, 0x100), 0x100) // `signature` offset.
            mstore(add(m, 0x120), 0x41) // `signature` length.
            mstore(add(m, 0x140), r)
            mstore(add(m, 0x160), s)
            mstore(add(m, 0x180), shl(248, v))
            if iszero(call(gas(), p, 0, add(m, 0x1c), 0x184, codesize(), 0x00)) {
                mstore(0x00, 0x6b836e6b) // `Permit2Failed()`.
                revert(0x1c, 0x04)
            }
        }
    }
}

// evm/lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol

// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/IERC20.sol)

// evm/lib/openzeppelin-contracts/contracts/utils/introspection/ERC165.sol

// OpenZeppelin Contracts (last updated v5.0.0) (utils/introspection/ERC165.sol)

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 */
abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

// evm/src/distribution/src/interfaces/ICalendarVester.sol

/// @notice Abstract contract to define common behavior for Calender type vesters, specifically to calculate the vested
/// amount
abstract contract CalendarVester {
    /**
     * @notice Get the vested amount for Calendar type vesters
     *
     * @param _unlockTimestamps array of unlock timestamps
     * @param _unlockPercents array of unlock percents
     * @param _totalAllocation total amount of tokens to be vested
     * @param _terminatedTimestamp the time when the allocation was terminated
     *
     * @return the vested amount
     */
    function _getVestedAmount(
        uint32[] memory _unlockTimestamps,
        uint256[] memory _unlockPercents,
        uint256 _totalAllocation,
        uint256 _terminatedTimestamp
    )
        internal
        view
        returns (uint256)
    {
        uint256 percent;
        uint32 blockTimestamp = uint32(block.timestamp);

        uint256 finalTimestamp;
        if (_terminatedTimestamp == 0) {
            finalTimestamp = blockTimestamp;
        } else {
            finalTimestamp = Math.min(_terminatedTimestamp, blockTimestamp);
        }

        for (uint256 i = 0; i < _unlockTimestamps.length; i++) {
            if (_unlockTimestamps[i] > finalTimestamp) {
                break;
            }
            percent += _unlockPercents[i];
        }

        // Perecent is in 10,000ths, so for precision we need to multipy then divide
        return Math.min(_totalAllocation, Math.mulDiv(_totalAllocation, percent, 10_000 * 100));
    }
}

// evm/lib/openzeppelin-contracts/contracts/utils/Multicall.sol

// OpenZeppelin Contracts (last updated v5.0.1) (utils/Multicall.sol)

/**
 * @dev Provides a function to batch together multiple calls in a single external call.
 *
 * Consider any assumption about calldata validation performed by the sender may be violated if it's not especially
 * careful about sending transactions invoking {multicall}. For example, a relay address that filters function
 * selectors won't filter calls nested within a {multicall} operation.
 *
 * NOTE: Since 5.0.1 and 4.9.4, this contract identifies non-canonical contexts (i.e. `msg.sender` is not {_msgSender}).
 * If a non-canonical context is identified, the following self `delegatecall` appends the last bytes of `msg.data`
 * to the subcall. This makes it safe to use with {ERC2771Context}. Contexts that don't affect the resolution of
 * {_msgSender} are not propagated to subcalls.
 */
abstract contract Multicall is Context {
    /**
     * @dev Receives and executes a batch of function calls on this contract.
     * @custom:oz-upgrades-unsafe-allow-reachable delegatecall
     */
    function multicall(bytes[] calldata data) external virtual returns (bytes[] memory results) {
        bytes memory context =
            msg.sender == _msgSender() ? new bytes(0) : msg.data[msg.data.length - _contextSuffixLength():];

        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            results[i] = Address.functionDelegateCall(address(this), bytes.concat(data[i], context));
        }
        return results;
    }
}

// evm/src/distribution/src/interfaces/IPostClaimHandler.sol

/// @dev the address for denoting whether direct claims are allowed
IPostClaimHandler constant DIRECT_CLAIM_HANDLER = IPostClaimHandler(address(0));

/// @notice Interface for post claim handlers
interface IPostClaimHandler {
    /**
     * @notice Implementing this method provides a way to claim vesting tokens and execute some custom action afterwards
     * @dev Implementors can assume that 'amount' amount of 'claimToken' has already been transferred to this contract
     * address.
     *      Implementors should:
     *        1. check if the calling contract is the vesting contract, and revert otherwise
     *        2. revert the transaction, if for any reasons this contract cannot execute the custom actions
     * @param claimToken Address of the vesting token.
     * @param amount The amount of vesting tokens that were claimed and transferred to this contract address.
     * @param originalBeneficiary The address of the user who was the original owner of the vesting tokens at the time
     * the vesting contract was created.
     * @param withdrawalAddress The latest owner of the vesting tokens which might be the same as the
     * 'originalBeneficiary' in case no ownership transfer took place.
     * @param allocationId The allocation id from which the withdrawn amount was taken.
     * @param extraData Any abi encoded extra data that is necessary for the custom action. For example in case of a
     * custom staking action, the user could state his
     *                  staking preference by providing extraData.
     */
    function handlePostClaim(
        IERC20 claimToken,
        uint256 amount,
        address originalBeneficiary,
        address withdrawalAddress,
        string memory allocationId,
        bytes memory extraData
    )
        external;
}

// evm/lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/utils/SafeERC20.sol)

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using Address for address;

    /**
     * @dev An operation with an ERC20 token failed.
     */
    error SafeERC20FailedOperation(address token);

    /**
     * @dev Indicates a failed `decreaseAllowance` request.
     */
    error SafeERC20FailedDecreaseAllowance(address spender, uint256 currentAllowance, uint256 requestedDecrease);

    /**
     * @dev Transfer `value` amount of `token` from the calling contract to `to`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transfer, (to, value)));
    }

    /**
     * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transferFrom, (from, to, value)));
    }

    /**
     * @dev Increase the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        forceApprove(token, spender, oldAllowance + value);
    }

    /**
     * @dev Decrease the calling contract's allowance toward `spender` by `requestedDecrease`. If `token` returns no
     * value, non-reverting calls are assumed to be successful.
     */
    function safeDecreaseAllowance(IERC20 token, address spender, uint256 requestedDecrease) internal {
        unchecked {
            uint256 currentAllowance = token.allowance(address(this), spender);
            if (currentAllowance < requestedDecrease) {
                revert SafeERC20FailedDecreaseAllowance(spender, currentAllowance, requestedDecrease);
            }
            forceApprove(token, spender, currentAllowance - requestedDecrease);
        }
    }

    /**
     * @dev Set the calling contract's allowance toward `spender` to `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful. Meant to be used with tokens that require the approval
     * to be set to zero before setting it to a non-zero value, such as USDT.
     */
    function forceApprove(IERC20 token, address spender, uint256 value) internal {
        bytes memory approvalCall = abi.encodeCall(token.approve, (spender, value));

        if (!_callOptionalReturnBool(token, approvalCall)) {
            _callOptionalReturn(token, abi.encodeCall(token.approve, (spender, 0)));
            _callOptionalReturn(token, approvalCall);
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address-functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data);
        if (returndata.length != 0 && !abi.decode(returndata, (bool))) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturn} that silents catches all reverts and returns a bool instead.
     */
    function _callOptionalReturnBool(IERC20 token, bytes memory data) private returns (bool) {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We cannot use {Address-functionCall} here since this should return false
        // and not revert is the subcall reverts.

        (bool success, bytes memory returndata) = address(token).call(data);
        return success && (returndata.length == 0 || abi.decode(returndata, (bool))) && address(token).code.length > 0;
    }
}

// evm/lib/openzeppelin-contracts/contracts/access/AccessControl.sol

// OpenZeppelin Contracts (last updated v5.0.0) (access/AccessControl.sol)

/**
 * @dev Contract module that allows children to implement role-based access
 * control mechanisms. This is a lightweight version that doesn't allow enumerating role
 * members except through off-chain means by accessing the contract event logs. Some
 * applications may benefit from on-chain enumerability, for those cases see
 * {AccessControlEnumerable}.
 *
 * Roles are referred to by their `bytes32` identifier. These should be exposed
 * in the external API and be unique. The best way to achieve this is by
 * using `public constant` hash digests:
 *
 * ```solidity
 * bytes32 public constant MY_ROLE = keccak256("MY_ROLE");
 * ```
 *
 * Roles can be used to represent a set of permissions. To restrict access to a
 * function call, use {hasRole}:
 *
 * ```solidity
 * function foo() public {
 *     require(hasRole(MY_ROLE, msg.sender));
 *     ...
 * }
 * ```
 *
 * Roles can be granted and revoked dynamically via the {grantRole} and
 * {revokeRole} functions. Each role has an associated admin role, and only
 * accounts that have a role's admin role can call {grantRole} and {revokeRole}.
 *
 * By default, the admin role for all roles is `DEFAULT_ADMIN_ROLE`, which means
 * that only accounts with this role will be able to grant or revoke other
 * roles. More complex role relationships can be created by using
 * {_setRoleAdmin}.
 *
 * WARNING: The `DEFAULT_ADMIN_ROLE` is also its own admin: it has permission to
 * grant and revoke this role. Extra precautions should be taken to secure
 * accounts that have been granted it. We recommend using {AccessControlDefaultAdminRules}
 * to enforce additional security measures for this role.
 */
abstract contract AccessControl is Context, IAccessControl, ERC165 {
    struct RoleData {
        mapping(address account => bool) hasRole;
        bytes32 adminRole;
    }

    mapping(bytes32 role => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with an {AccessControlUnauthorizedAccount} error including the required role.
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role);
        _;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControl).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view virtual returns (bool) {
        return _roles[role].hasRole[account];
    }

    /**
     * @dev Reverts with an {AccessControlUnauthorizedAccount} error if `_msgSender()`
     * is missing `role`. Overriding this function changes the behavior of the {onlyRole} modifier.
     */
    function _checkRole(bytes32 role) internal view virtual {
        _checkRole(role, _msgSender());
    }

    /**
     * @dev Reverts with an {AccessControlUnauthorizedAccount} error if `account`
     * is missing `role`.
     */
    function _checkRole(bytes32 role, address account) internal view virtual {
        if (!hasRole(role, account)) {
            revert AccessControlUnauthorizedAccount(account, role);
        }
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) public view virtual returns (bytes32) {
        return _roles[role].adminRole;
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleGranted} event.
     */
    function grantRole(bytes32 role, address account) public virtual onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleRevoked} event.
     */
    function revokeRole(bytes32 role, address account) public virtual onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been revoked `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `callerConfirmation`.
     *
     * May emit a {RoleRevoked} event.
     */
    function renounceRole(bytes32 role, address callerConfirmation) public virtual {
        if (callerConfirmation != _msgSender()) {
            revert AccessControlBadConfirmation();
        }

        _revokeRole(role, callerConfirmation);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        bytes32 previousAdminRole = getRoleAdmin(role);
        _roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    /**
     * @dev Attempts to grant `role` to `account` and returns a boolean indicating if `role` was granted.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleGranted} event.
     */
    function _grantRole(bytes32 role, address account) internal virtual returns (bool) {
        if (!hasRole(role, account)) {
            _roles[role].hasRole[account] = true;
            emit RoleGranted(role, account, _msgSender());
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Attempts to revoke `role` to `account` and returns a boolean indicating if `role` was revoked.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleRevoked} event.
     */
    function _revokeRole(bytes32 role, address account) internal virtual returns (bool) {
        if (hasRole(role, account)) {
            _roles[role].hasRole[account] = false;
            emit RoleRevoked(role, account, _msgSender());
            return true;
        } else {
            return false;
        }
    }
}

// evm/src/distribution/src/interfaces/AirlockTypes.sol

/// @dev error thrown when token address is 0
error ZeroToken();
/// @dev error thrown when beneficiary address is 0
error ZeroBeneficiary();
/// @dev error thrown when amount is 0
error AmountZero();
/// @dev error thrown when amount is greater than max allocation
error AmountGreaterThanMaxAllocation();
/// @dev error thrown when the number of periods is 0
error ZeroPeriods();
/// @dev error thrown when the total percentage doesn't add up to 100
error Not100Percent();
/// @dev error thrown when the address is not the beneficiary
error NotBeneficiary();
/// @dev error thrown when the allocation is not cancellable
error NotCancellable();
/// @dev error thrown when the allocation is not revokable
error NotRevokable();
/// @dev error thrown when the allocation is not transferable
error NotTransferable();

/// @dev error thrown when the allocation is not funded
error NotFunded();
/// @dev error thrown when the timestamp provided is invalid
error InvalidTimestamp();
/// @dev error thrown when to many timestamps are provided
error TooManyTimestamps();
/// @dev error thrown when the supplied beneficiary address is the same as an others
error SameBeneficiaryAddress();

/// @dev error thrown when a calendar with the same id already exists
error CalendarExists();
/// @dev error thrown when a calendar doesn't exist or invalid
error InvalidCalendar();
/// @dev error thrown when array length of two or more arrays mismatch
error ArrayLengthMismatch();
/// @dev error thrown when array content of two or more arrays mismatch
error ArrayMismatch(uint16 errCode, uint16 index);
/// @dev error thrown when array length is zero
error ZeroArrayLength();
/// @dev error thrown when timestamps are not ordered
error UnorderedTimestamp();

/// @dev error thrown when an interval with the same id already exists
error IntervalExists();
/// @dev error thrown when an interval doesn't exist or invalid
error InvalidInterval();
/// @dev error thrown when an an amount in an interval is invalid
error InvalidAmount();
/// @dev error thrown when the cliff in an interval is invalid
error InvalidCliff();
/// @dev error thrown when a period in an interval is invalid
error InvalidPeriod();

/// @dev error thrown when the withdrawal amount is invalid
error InvalidWithdrawal();

/// @dev error thrown when the allocation is already terminated
error AlreadyTerminated();
/// @dev error thrown when the allocation is already fully unlocked
error AlreadyFullyUnlocked();

/// @dev error thrown when the token is invalid
error InvalidToken();
/// @dev error thrown when the allocation type is invalid
error InvalidAllocationType();
/// @dev error thrown when the token is deflationary
error DeflationaryTokensNotSupported();
/// @dev error thrown when the allocation is invalid
error InvalidAllocation();
/// @dev error thrown when the funds are not sufficient
error InsufficientFunds();
/// @dev error thrown when Merkle proof is invalid
error InvalidMerkleProof();

/// @dev error thrown when the fee collector is invalid
error InvalidFeeCollector();
/// @dev error thrown when the fee setter is invalid
error InvalidFeeSetter();
/// @dev error thrown when the fees sent with the claim request doesn't match the claim fee
error InvalidFeeFundsSent();
/// @dev error thrown when the claim fee is being set to a higher value than the maximum claim fee
error ClaimFeeExceedsMaximum();

/// @dev error thrown when the claim fee handler is already whitelisted
error ClaimHandlerAlreadyWhitelisted();
/// @dev error thrown when the the claim fee handler is not yet whitelisted
error ClaimHandlerNotYetWhitelisted();
/// @dev error thrown when post claim handler is not whitelisted
error PostClaimHandlerNotWhitelisted();

/**
 * @notice The mutable state of an allocation
 *
 * @param withdrawalAddress can be overriden when the schedule is transferable
 * @param terminatedTimestamp Sentinel values: 0 is active, 1 is revoked, any other value is the time the calendar was
 * cancelled
 * @param withdrawn represents the amount withdrawn by the beneficiary
 * @param terminatedWithdrawn represents the amount withdrawn from terminated funds, merkle vester does not support
 * funding indivual allocations
 * @param fundedAmount amount of tokens funded for this distribution, merkle vester does not support funding indivual
 * allocations
 * @param terminatedAmount amount of tokens terminated for this distribution, merkle vester does not support funding
 * indivual allocations
 */
struct DistributionState {
    address withdrawalAddress;
    uint32 terminatedTimestamp;
    uint256 withdrawn;
    uint256 terminatedWithdrawn;
    uint256 fundedAmount;
    uint256 terminatedAmount;
}

/**
 * @notice The immutable data for an allocation,
 * @dev solidity does not support immutablability outside of compile time, contracts must not implement mutability
 *
 * @param id id of the allocation
 * @param originalBeneficiary original beneficiary address, withdrawalAddress in DistributionState should be used for
 * transfers
 * @param totalAllocation total amount of tokens to vest in the allocaiton
 * @param cancelable flag to allow for the allocation to be cancelled, unvested funds are returned to the benefactor
 * vested funds remain withdrawable by the beneficiary
 * @param revokable flag to allow for the allocation to be revoked, all funds not already withdrawn are returned to the
 * benefactor
 * @param transferableByAdmin flag to allow for the allocation to be transferred by the admin
 * @param transferableByBeneficiary flag to allow for the allocation to be transferred by the beneficiary
 */
struct Allocation {
    string id;
    address originalBeneficiary;
    uint256 totalAllocation;
    bool cancelable;
    bool revokable;
    bool transferableByAdmin;
    bool transferableByBeneficiary;
}

/**
 * @notice Immutable unlock schedule for calendar allocations
 * @dev solidity does not support immutablability outside of compile time, contracts must not implement mutability
 *
 * @param unlockScheduleId id of the allocation
 * @param unlockTimestamps sequence of timestamps when funds will unlock
 * @param unlockPercents sequence of percents that unlock at each timestamp, in 10,000ths
 */
struct CalendarUnlockSchedule {
    string unlockScheduleId; // Workaround for Internal or recursive type is not allowed for public state variables
    uint32[] unlockTimestamps;
    uint256[] unlockPercents;
}

/**
 * @notice Immutable unlock schedule for interval allocations
 * @dev solidity does not support immutablability outside of compile time, contracts must not implement mutability
 *
 * @param unlockScheduleId id of the allocation
 * @param pieces sequence of pieces representing phases of the unlock schedule, percents of pieces must sum to 100%
 */
struct IntervalUnlockSchedule {
    string unlockScheduleId; // Workaround for Internal or recursive type is not allowed for public state variables
    Piece[] pieces;
}

/**
 * @notice Represents a phase of an interval unlock schedule
 * @dev solidity does not support immutablability outside of compile time, contracts must not implement mutability
 *
 * @param startDate start timestamp of the piece
 * @param periodLength time length of the piece
 * @param numberOfPeriods how many periods for this piece
 * @param percent the total percent, in 10,000ths that will unlock over the piece
 */
struct Piece {
    uint32 startDate;
    uint32 periodLength;
    uint32 numberOfPeriods;
    uint32 percent;
}

/// @notice Holding allocation data for Calendar style vesting, including both immutable and mutable data and a
/// reference to the calendar schedule
struct CalendarAllocation {
    Allocation allocation;
    // Many allocations share the same unlock schedule so we can save gas by referencing the same schedule
    // the mapping key could be smaller than string but this will help sync with the web application
    string calendarUnlockScheduleId;
    DistributionState distributionState;
}

/// @notice Holding allocation data for Interval style vesting, including both immutable and mutable data and a
/// reference to the interval schedule
struct IntervalAllocation {
    Allocation allocation;
    string intervalUnlockScheduleId;
    DistributionState distributionState;
}

// evm/src/distribution/src/MerkleValidator.sol

/// @notice Utility contract to verify that a leaf is included in the Merkle tree
contract MerkleValidator {
    /**
     * @notice Verify verify a leaf is included in the Merkle tree
     * @dev throws if the verification fails
     *
     * @param merkleRoot the root of the Merkle tree
     * @param leafArguments the leaf that needs to be verified whether it is part of the tree
     * @param proof the inclusion proof
     */
    function validateLeaf(bytes32 merkleRoot, bytes memory leafArguments, bytes32[] calldata proof) external pure {
        bytes32 leaf = keccak256(abi.encodePacked(leafArguments));
        bool isValidLeaf = MerkleProof.verify(proof, merkleRoot, leaf);
        if (!isValidLeaf) revert InvalidMerkleProof();
    }
}

// evm/src/distribution/src/interfaces/IAirlockBase.sol

/**
 * @title Defines the common errors, structures, and functions for managing vesting and related actions.
 */
abstract contract IAirlockBase is AccessControl, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @dev storing the whitelisted post claim handlers
    EnumerableSet.AddressSet private postClaimHandlerWhitelist;

    /// @dev total withdrawn from the vester contract
    uint256 public totalWithdrawn;

    /// @dev emitted when an allocation is cancelled
    /// @param id allocation id
    event ScheduleCanceled(string id);

    /// @dev emitted when a schedule is revoked
    /// @param id allocation id
    event ScheduleRevoked(string id);

    /// @dev emitted when the beneficiary is transferred
    /// @param id allocation id
    /// @param newBeneficiary the new beneficiary
    event TransferredBeneficiary(string id, address newBeneficiary);

    /// @dev the vesting token
    address public immutable token;
    /// @dev the role for the benefactor
    bytes32 public constant BENEFACTOR = keccak256("BENEFACTOR");
    /// @dev the role for managing post claim handlers
    bytes32 public constant POST_CLAIM_HANDLER_MANAGER = keccak256("POST_CLAIM_HANDLER_MANAGER");

    /**
     * @notice Constructor to create an IAirlockBase contract
     *
     * @param _token token address this vesting contract will distribute
     * @param _benefactor inital administator and benefactor of the contract
     * @param _postClaimHandlers an array of post claim handlers to be whitelisted
     */
    constructor(address _token, address _benefactor, IPostClaimHandler[] memory _postClaimHandlers) {
        if (_token == address(0)) revert ZeroToken();
        if (_benefactor == address(0)) revert ZeroBeneficiary();
        token = _token;
        _grantRole(DEFAULT_ADMIN_ROLE, _benefactor); // The benefactor specified in the deploy can grant and revoke
            // benefactor roles using the AccessControl interface
        _grantRole(BENEFACTOR, _benefactor);
        _grantRole(POST_CLAIM_HANDLER_MANAGER, _benefactor);

        uint256 _postCLaimHandlersLength = _postClaimHandlers.length;
        for (uint256 i; i < _postCLaimHandlersLength; ++i) {
            postClaimHandlerWhitelist.add(address(_postClaimHandlers[i]));
        }
    }

    /**
     * @notice Returns the whitelisted post claim handlers
     * @dev if the direct claim feature is enabled, this method will return an array containing
     *      a post claim handler with address(0)
     *
     * @return postClaimHandlers the whitelisted
     */
    function getPostClaimHandlers() external view returns (address[] memory postClaimHandlers) {
        uint256 arrLength = postClaimHandlerWhitelist.length();
        postClaimHandlers = new address[](arrLength);
        for (uint256 i; i < arrLength; ++i) {
            postClaimHandlers[i] = (postClaimHandlerWhitelist.at(i));
        }
    }

    /**
     * @notice Adds a post claim handler to the whitelist
     *
     * @param postClaimHandler the post claim handler to be whitelisted
     */
    function addPostClaimHandlerToWhitelist(IPostClaimHandler postClaimHandler)
        external
        onlyRole(POST_CLAIM_HANDLER_MANAGER)
    {
        if (!postClaimHandlerWhitelist.add(address(postClaimHandler))) {
            revert ClaimHandlerAlreadyWhitelisted();
        }
    }

    /**
     * @notice Removes a post claim handler from the whitelist
     *
     * @param postClaimHandler the post claim handler to be removed from the whitelist
     */
    function removePostClaimHandlerToWhitelist(IPostClaimHandler postClaimHandler)
        external
        onlyRole(POST_CLAIM_HANDLER_MANAGER)
    {
        if (!postClaimHandlerWhitelist.remove(address(postClaimHandler))) {
            revert ClaimHandlerNotYetWhitelisted();
        }
    }

    /**
     * @notice Token rescue functionality, allows the benefactor to withdraw any other ERC20 tokens that were sent to
     * the contract by mistake
     *
     * @param _errantTokenAddress address of the token to rescue, must not be the token the vesting contract manages
     * @param _rescueAddress address to send the recovered funds to
     */
    function rescueTokens(
        address _errantTokenAddress,
        address _rescueAddress
    )
        external
        nonReentrant
        onlyRole(BENEFACTOR)
    {
        if (_errantTokenAddress == token) revert InvalidToken();
        SafeERC20.safeTransfer(
            IERC20(_errantTokenAddress), _rescueAddress, IERC20(_errantTokenAddress).balanceOf(address(this))
        );
    }

    /**
     * @notice Internal function to update state and withdraw beneficiary funds
     *
     * @param allocation the allocation to withdraw from
     * @param distributionState the storage pointer to the distribution state for the allocation
     * @param withdrawableAmount amount of tokens that can be withdrawn by the beneficiary
     * @param requestedWithdrawalAmount amount of tokens beneficiary requested to withdraw, or 0 for all available funds
     * @param postClaimHandler post claim handler to call as part of the withdrawal process
     * @param extraData any abi encoded extra data that is necessary for the custom action. For example in case of a
     * custom staking action, the user could state his
     *                  staking preference by providing extraData
     */
    function _withdrawToBeneficiary(
        Allocation memory allocation,
        DistributionState storage distributionState,
        uint256 withdrawableAmount,
        uint256 requestedWithdrawalAmount,
        IPostClaimHandler postClaimHandler,
        bytes memory extraData
    )
        internal
        _validateWithdrawalInvariants(distributionState, allocation, withdrawableAmount)
    {
        if (requestedWithdrawalAmount > withdrawableAmount) revert InsufficientFunds();
        if (withdrawableAmount == 0) revert AmountZero();

        // withdrawal amount is optional, if not provided, withdraw the entire withdrawable amount
        if (requestedWithdrawalAmount == 0) requestedWithdrawalAmount = withdrawableAmount;
        withdrawableAmount = Math.min(withdrawableAmount, requestedWithdrawalAmount);

        // If the withdrawal address (set in the case of beneficiary transfer) is not set, use the original beneficiary
        address withdrawalAddress = (distributionState.withdrawalAddress == address(0))
            ? allocation.originalBeneficiary
            : distributionState.withdrawalAddress;

        // Update the state
        distributionState.withdrawn += withdrawableAmount;
        totalWithdrawn += withdrawableAmount;

        if (!postClaimHandlerWhitelist.contains(address(postClaimHandler))) {
            revert PostClaimHandlerNotWhitelisted();
        }
        // If post claim handler is set to DIRECT_CLAIM_HANDLER, it means the claim token has to be directly transferred
        // to the beneficiary
        // without any interaction with an integration contract.
        if (postClaimHandler == DIRECT_CLAIM_HANDLER) {
            SafeERC20.safeTransfer(IERC20(token), withdrawalAddress, withdrawableAmount);
        } else {
            // Claim tokens have to be forwarded to an integration contract.
            SafeERC20.safeTransfer(IERC20(token), address(postClaimHandler), withdrawableAmount);

            // any error in the postClam handler will revert the entire transaction including the transfer above
            postClaimHandler.handlePostClaim(
                IERC20(token),
                withdrawableAmount,
                allocation.originalBeneficiary,
                withdrawalAddress,
                allocation.id,
                extraData
            );
        }
    }

    /**
     * @notice Internal Transfer ownership of a calendar's beneficiary address, authorized by benefactor or beneficiary
     * if enabled
     *
     * @param state the storage pointer to the distribution state for the allocation
     * @param allocation the allocation to withdraw from
     * @param _newAddress address to transfer ownership to
     */
    function _transferBeneficiaryAddress(
        DistributionState storage state,
        Allocation memory allocation,
        address _newAddress
    )
        internal
    {
        if (_newAddress == address(0)) revert ZeroBeneficiary();

        if (_newAddress == state.withdrawalAddress) revert SameBeneficiaryAddress();

        bool authorizedByAdmin = (AccessControl.hasRole(BENEFACTOR, msg.sender) && allocation.transferableByAdmin);
        bool authorizedByBeneficiary = (msg.sender == state.withdrawalAddress && allocation.transferableByBeneficiary);
        if (!(authorizedByAdmin || authorizedByBeneficiary)) revert NotTransferable();

        state.withdrawalAddress = _newAddress;
        emit TransferredBeneficiary(allocation.id, _newAddress);
    }

    /**
     * @notice Internal verification and transfer of funds from the sender to the contract
     * @dev Should only be called in nonReentrant functions. Additionally as an extra precaution function should be
     * called before mutating state
     *      as a protection against tokens with callbacks see
     * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/extensions/ERC4626.sol#L240
     * @param _amountToFund amount of funds to transfer to the contract
     */
    function _transferInFunds(uint256 _amountToFund) internal {
        if (_amountToFund == 0) revert AmountZero();
        uint256 currentBalance = IERC20(token).balanceOf(address(this));
        SafeERC20.safeTransferFrom(IERC20(token), msg.sender, address(this), _amountToFund);
        if (currentBalance + _amountToFund != IERC20(token).balanceOf(address(this))) {
            revert DeflationaryTokensNotSupported();
        }
    }

    /**
     * @notice Internal withdrawal invariant validation, an additional safety measure against over-withdrawing
     *
     * @param state the storage pointer to the distribution state for the allocation
     * @param allocation the allocation to withdraw from
     * @param amountWithdrawing the amount to withdraw
     */
    modifier _validateWithdrawalInvariants(
        DistributionState storage state,
        Allocation memory allocation,
        uint256 amountWithdrawing
    ) {
        if (state.withdrawn + state.terminatedWithdrawn + amountWithdrawing > allocation.totalAllocation) {
            revert InvalidWithdrawal();
        }
        _;
        if (state.withdrawn + state.terminatedWithdrawn > allocation.totalAllocation) revert InvalidWithdrawal();
    }
}

// evm/src/distribution/src/IMerkleVester.sol

/// @notice Abstract contract to define common behavior for Merkle type vesters
interface IMerkleVester {
    /**
     * @notice Calculates the hash of a given Calendar allocation leaf
     *
     * @param allocationType 'calendar' or 'interval'
     * @param allocation allocation data
     * @param unlockSchedule calendar unlock schedule
     *
     * @return the hash of a given Calendar allocation leaf
     */
    function getCalendarLeafHash(
        string calldata allocationType,
        Allocation calldata allocation,
        CalendarUnlockSchedule calldata unlockSchedule
    )
        external
        pure
        returns (bytes32);

    /**
     * @notice Calculates the hash of a given Interval allocation leaf
     *
     * @param allocationType 'calendar' or 'interval'
     * @param allocation allocation data
     * @param unlockSchedule interval unlock schedule
     *
     * @return the hash of a given Interval allocation leaf
     */
    function getIntervalLeafHash(
        string calldata allocationType,
        Allocation calldata allocation,
        IntervalUnlockSchedule calldata unlockSchedule
    )
        external
        pure
        returns (bytes32);

    /**
     * @notice Decodes calendar allocation data from decodable arguments and state stored on chain
     *
     * @param rootIndex the index of the merkle root the allocation is in
     * @param decodableArgs the allocation data that constitutes the leaf to be decoded and verified
     * @param proof proof data of sibling leaves to verify the leaf is included in the root
     *
     * @return calendarAllocation decoded calendar allocation
     * @return calendarUnlockSchedule decoded calendar unlock schedule
     */
    function getCalendarLeafAllocationData(
        uint32 rootIndex,
        bytes calldata decodableArgs,
        bytes32[] calldata proof
    )
        external
        view
        returns (CalendarAllocation memory calendarAllocation, CalendarUnlockSchedule memory calendarUnlockSchedule);

    /**
     * @notice Decodes interval allocation data from decodable arguments and state stored on chain
     *
     * @param rootIndex the index of the merkle root the allocation is in
     * @param decodableArgs the allocation data that constitutes the leaf to be decoded and verified
     * @param proof proof data of sibling leaves to verify the leaf is included in the root
     *
     * @return intervalAllocation decoded interval allocation
     * @return intervalUnlockSchedule decoded interval unlock schedule
     */
    function getIntervalLeafAllocationData(
        uint32 rootIndex,
        bytes calldata decodableArgs,
        bytes32[] calldata proof
    )
        external
        view
        returns (IntervalAllocation memory intervalAllocation, IntervalUnlockSchedule memory intervalUnlockSchedule);

    /**
     * @notice Decodes allocation data from decodable arguments, works for both calendar and interval allocations
     *
     * @param rootIndex the index of the merkle root the allocation is in
     * @param decodableArgs the allocation data that constitutes the leaf to be decoded and verified
     * @param proof proof data of sibling leaves to verify the leaf is included in the root
     *
     * @return decoded allocation
     */
    function getLeafJustAllocationData(
        uint32 rootIndex,
        bytes memory decodableArgs,
        bytes32[] calldata proof
    )
        external
        view
        returns (Allocation memory);

    /**
     * @notice Adds additional allocations in an append only manner
     * @dev dapp is responsible for ensuring funding across all allocations otherwise withdrawals will be fulfilled
     * first come first served
     *
     * @param merkleRoot the additional merkle root to append representing additional allocations
     *
     * @return the new lenght of the number of merkle roots array minus 1
     */
    function addAllocationRoot(bytes32 merkleRoot) external returns (uint256);

    /**
     * @notice Funds the contract with the specified amount of tokens
     * @dev MerkleVester contracts are funded as a whole rather than funding individual allocations
     */
    function fund(uint256 amount) external;

    /**
     * @notice Defunds the contract the specified amount of tokens
     * @dev using defund can result in underfunding the total liabilies of the allocations, in which case allocations
     * will be served on a first come first serve basis
     */
    function defund(uint256 amount) external;

    /**
     * @notice Withdraws vested funds from the contract to the beneficiary
     * @dev if direct claim feature is disabled, then this method should not be called
     *
     * @param withdrawalAmount optional amount to withdraw, specify 0 to withdraw all vested funds. If amount specified
     * is greater than vested amount this call will fail since that implies a incorrect intention
     * @param rootIndex the index of the merkle root the allocation is in
     * @param decodableArgs the allocation data that constitutes the leaf to be decoded and verified
     * @param proof proof data of sibling leaves to verify the leaf is included in the root
     */
    function withdraw(
        uint256 withdrawalAmount,
        uint32 rootIndex,
        bytes memory decodableArgs,
        bytes32[] calldata proof
    )
        external
        payable;

    /**
     * @notice Withdraws vested funds from the contract to the beneficiary
     *
     * @param withdrawalAmount optional amount to withdraw, specify 0 to withdraw all vested funds. If amount specified
     * is greater than vested amount this call will fail since that implies a incorrect intention
     * @param rootIndex the index of the merkle root the allocation is in
     * @param decodableArgs the allocation data that constitutes the leaf to be decoded and verified
     * @param proof proof data of sibling leaves to verify the leaf is included in the root
     * @param postClaimHandler the tokens will be automatically transferred to postClaimHandler contract, after which
     * the handlePostClaim will be automatically called
     * @param extraData extra data that will be passed to the post claim handler
     */
    function withdraw(
        uint256 withdrawalAmount,
        uint32 rootIndex,
        bytes memory decodableArgs,
        bytes32[] calldata proof,
        IPostClaimHandler postClaimHandler,
        bytes calldata extraData
    )
        external
        payable;

    /**
     * @notice Transfers the beneficiary address of the allocation, only for allocations either transferable by the
     * beneficiary or benefactor
     *
     * @param newBeneficiaryAddress the new beneficiary address
     * @param rootIndex the index of the merkle root the allocation is in
     * @param decodableArgs the allocation data that constitutes the leaf to be decoded and verified
     * @param proof proof data of sibling leaves to verify the leaf is included in the root
     */
    function transferBeneficiaryAddress(
        address newBeneficiaryAddress,
        uint32 rootIndex,
        bytes memory decodableArgs,
        bytes32[] calldata proof
    )
        external;

    /**
     * @notice Cancels the allocation, already vested funds remain withdrawable to the beneficiary
     * @dev don't need to track the terminated amount since merkle vester doesn't have per allocation underfunding
     *
     * @param rootIndex the index of the merkle root the allocation is in
     * @param decodableArgs the allocation data that constitutes the leaf to be decoded and verified
     * @param proof proof data of sibling leaves to verify the leaf is included in the root
     */
    function cancel(uint32 rootIndex, bytes memory decodableArgs, bytes32[] calldata proof) external;

    /**
     * @notice Revokes the allocation, unwithdrawn funds are no longer withdrawable to the beneficiary
     * @dev don't need to track the terminated amount since merkle vester doesn't have per allocation underfunding
     *
     * @param rootIndex the index of the merkle root the allocation is in
     * @param decodableArgs the allocation data that constitutes the leaf to be decoded and verified
     * @param proof proof data of sibling leaves to verify the leaf is included in the root
     */
    function revoke(uint32 rootIndex, bytes memory decodableArgs, bytes32[] calldata proof) external;

    /**
     * @notice For exceptional circumstances, it would be prohibitively expensive to run cancellation logic per
     * allocation
     */
    function revokeAll() external;
}

// evm/src/distribution/src/interfaces/IIntervalVester.sol

/// @notice Abstract contract to define common behavior for Interval type vesters, specifically to calculate the vested
/// amount
abstract contract IntervalVester is IAirlockBase {
    /**
     * @notice Gets the vested amount of tokens for a schedule
     * @dev iterates over the pieces and calculates the number of tokens that have vested
     *
     * @param interval the interval data for which to calculate vested amount
     * @param schedule the unlock schedule for which to calculate vested amount
     *
     * @return amount of tokens vested
     */
    function _getVestedAmount(
        IntervalAllocation memory interval,
        IntervalUnlockSchedule memory schedule
    )
        internal
        view
        returns (uint256)
    {
        uint256 finalTimestamp = _getLastVestingTimestamp(interval.distributionState.terminatedTimestamp);

        uint256 vestingEndTimestamp = _getPieceEndTime(schedule.pieces[schedule.pieces.length - 1]);

        // Ensure full distribution without any rounding if we are past the end of the vesting schedule
        if (finalTimestamp >= vestingEndTimestamp) return interval.allocation.totalAllocation;

        // brute force iterate over schedule components
        uint256 currVested;

        for (uint256 index; index < schedule.pieces.length; index++) {
            currVested += _componentVested(
                schedule.pieces[index].startDate,
                schedule.pieces[index].periodLength,
                schedule.pieces[index].numberOfPeriods,
                schedule.pieces[index].percent,
                finalTimestamp,
                interval.allocation.totalAllocation
            );
        }

        return Math.min(interval.allocation.totalAllocation, currVested);
    }

    /**
     * @notice Gets the timestamp when the piece is fully vested
     *
     * @param piece one piece that makes up the allocation
     *
     * @return the timestamp when the piece is fully vested
     */
    function _getPieceEndTime(Piece memory piece) internal pure returns (uint32) {
        return (piece.startDate + (piece.periodLength * piece.numberOfPeriods));
    }

    /**
     * @notice Gets the vested amount of tokens for a schedule
     * @dev calculates the number of tokens that have vested for a single component
     *
     * @param startDate the start date of the component
     * @param periodLength the length of each period
     * @param numberOfPeriods the number of periods in the component
     * @param percent the percent of tokens that is released in the component
     * @param blockTimestamp the current block timestamp
     *
     * @return amount of tokens vested
     *
     */
    function _componentVested(
        uint256 startDate,
        uint256 periodLength,
        uint256 numberOfPeriods,
        uint256 percent,
        uint256 blockTimestamp,
        uint256 totalAllocation
    )
        internal
        pure
        returns (uint256)
    {
        if (blockTimestamp < startDate) {
            return 0;
        }
        uint256 elapsedTime = blockTimestamp - startDate;
        uint256 fullyVestedPeriods = elapsedTime / periodLength;

        if (fullyVestedPeriods > numberOfPeriods) {
            fullyVestedPeriods = numberOfPeriods;
        }

        uint256 amount = Math.mulDiv(totalAllocation, percent, 10_000 * 100);

        return (amount * fullyVestedPeriods) / numberOfPeriods;
    }

    /**
     * @notice Gets the timestamp until the vesting should be calculated
     *
     * @param terminatedTimestamp zero if the allocation was not terminated, non-zero if the allocation was terminated
     * denoting the termination time
     *
     * @return the timestamp until the vesting should be calculated
     *
     */
    function _getLastVestingTimestamp(uint256 terminatedTimestamp) internal view returns (uint256) {
        if (terminatedTimestamp != 0) {
            return Math.min(block.timestamp, terminatedTimestamp);
        } else {
            return block.timestamp;
        }
    }
}

// evm/src/distribution/src/MerkleVester.sol

/**
 * @notice Vesting contract that uses merkle trees to scale to millions of allocations
 */
contract MerkleVester is IAirlockBase, IMerkleVester, IntervalVester, CalendarVester, MerkleValidator, Multicall {
    /// @dev maximum amount of claim fee in wei
    uint256 immutable maxClaimFee;

    /// @dev true, if claim fee should only be payed for the first claim of an allocation, false otherwise
    bool immutable shouldPayClaimFeeOnlyOnce;

    /// @dev mapping allocation id to a boolean to store allocation ids for which fee was already payed
    mapping(string => bool) private feeAlreadyPayed;

    /// @dev version number of the vester contract
    string public constant version = "dist_v2.1.2";

    /**
     * @dev lazily store the mutable state as allocaitons are interacted with
     */
    mapping(string => DistributionState) public schedules;
    /**
     * @dev new batches of allocations are added as an additional merkle root append only to keep existing allocations
     * immutable
     */
    bytes32[] public merkleRoots;

    /// @dev claim fee in wei
    uint256 public claimFee;

    /// @dev address where the fees will be transferred
    /// valid states for feeCollector, feeSetter:
    ///      1. feeCollector = address(0), feeSetter = address(0): Claim fees permanently disabled.
    ///      2. feeCollector != address(0), feeSetter = address(0): Claim fee is fixed at initialization and cannot be
    /// updated.
    ///      3. feeCollector != address(0), feeSetter != address(0): Claim fee can be updated by feeSetter.
    address public immutable feeCollector;

    /// @dev address who can update the fee
    address public immutable feeSetter;
    /// @dev role for the fee setter
    bytes32 public constant FEE_SETTER_ROLE = keccak256("FEE_SETTER_ROLE");

    /**
     * @notice Constructor to create a MerkleVester contract
     *
     * @param token token address this vesting contract will distribute
     * @param  benefactor inital administator and benefactor of the contract
     * @param _claimFee claim fee in wei
     * @param _feeCollector address where the fees will be transferred
     * @param _feeSetter  address who can update the fee
     * @param _postClaimHandlers an array of post claim handlers to be whitelisted
     * @param _maxClaimFee the maximum claim fee
     * @param _shouldPayClaimFeeOnlyOnce true, if claim fee should only be payed for the first claim of an allocation,
     * false otherwise
     */
    constructor(
        address token,
        address benefactor,
        uint256 _claimFee,
        address _feeCollector,
        address _feeSetter,
        IPostClaimHandler[] memory _postClaimHandlers,
        uint256 _maxClaimFee,
        bool _shouldPayClaimFeeOnlyOnce
    )
        IAirlockBase(token, benefactor, _postClaimHandlers)
    {
        if (_claimFee > _maxClaimFee) revert ClaimFeeExceedsMaximum();
        claimFee = _claimFee;
        maxClaimFee = _maxClaimFee;
        shouldPayClaimFeeOnlyOnce = _shouldPayClaimFeeOnlyOnce;

        if (_feeCollector == address(0)) {
            if (_feeSetter != address(0)) revert InvalidFeeSetter();
            if (_claimFee > 0) revert InvalidFeeCollector();
        }
        feeCollector = _feeCollector;

        if (_feeSetter != address(0)) {
            _grantRole(FEE_SETTER_ROLE, _feeSetter);
        }
        feeSetter = _feeSetter;
    }

    /// @inheritdoc IMerkleVester
    function getCalendarLeafHash(
        string calldata allocationType,
        Allocation calldata allocation,
        CalendarUnlockSchedule calldata unlockSchedule
    )
        external
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(allocationType, allocation, unlockSchedule));
    }

    /// @inheritdoc IMerkleVester
    function getIntervalLeafHash(
        string calldata allocationType,
        Allocation calldata allocation,
        IntervalUnlockSchedule calldata unlockSchedule
    )
        external
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(allocationType, allocation, unlockSchedule));
    }

    /// @inheritdoc IMerkleVester
    function getCalendarLeafAllocationData(
        uint32 rootIndex,
        bytes calldata decodableArgs,
        bytes32[] calldata proof
    )
        external
        view
        returns (CalendarAllocation memory, CalendarUnlockSchedule memory)
    {
        (
            string memory allocationType,
            Allocation memory allocation,
            CalendarUnlockSchedule memory calendarUnlockSchedule
        ) = abi.decode(decodableArgs, (string, Allocation, CalendarUnlockSchedule));
        this.validateLeaf(merkleRoots[rootIndex], decodableArgs, proof);

        DistributionState memory distributionState = schedules[allocation.id];

        return (
            CalendarAllocation(allocation, calendarUnlockSchedule.unlockScheduleId, distributionState),
            calendarUnlockSchedule
        );
    }

    /// @inheritdoc IMerkleVester
    function getIntervalLeafAllocationData(
        uint32 rootIndex,
        bytes calldata decodableArgs,
        bytes32[] calldata proof
    )
        external
        view
        returns (IntervalAllocation memory, IntervalUnlockSchedule memory)
    {
        (
            string memory allocationType,
            Allocation memory allocation,
            IntervalUnlockSchedule memory intervalUnlockSchedule
        ) = abi.decode(decodableArgs, (string, Allocation, IntervalUnlockSchedule));
        this.validateLeaf(merkleRoots[rootIndex], decodableArgs, proof);

        DistributionState memory distributionState = schedules[allocation.id];

        return (
            IntervalAllocation(allocation, intervalUnlockSchedule.unlockScheduleId, distributionState),
            intervalUnlockSchedule
        );
    }

    /// @inheritdoc IMerkleVester
    function getLeafJustAllocationData(
        uint32 rootIndex,
        bytes memory decodableArgs,
        bytes32[] calldata proof
    )
        external
        view
        returns (Allocation memory)
    {
        this.validateLeaf(merkleRoots[rootIndex], decodableArgs, proof);
        (, Allocation memory allocation) = abi.decode(decodableArgs, (string, Allocation));
        return allocation;
    }

    /// @inheritdoc IMerkleVester
    function addAllocationRoot(bytes32 merkleRoot) external nonReentrant onlyRole(BENEFACTOR) returns (uint256) {
        merkleRoots.push() = merkleRoot;
        return merkleRoots.length - 1;
    }

    /// @notice Sets the claim fee in wei
    function setClaimFee(uint256 _claimFee) external onlyRole(FEE_SETTER_ROLE) {
        if (_claimFee > maxClaimFee) revert ClaimFeeExceedsMaximum();
        if (feeCollector == address(0)) revert InvalidFeeCollector();
        claimFee = _claimFee;
    }

    /// @inheritdoc IMerkleVester
    function fund(uint256 amount) external override nonReentrant {
        _transferInFunds(amount);
    }

    /// @inheritdoc IMerkleVester
    function defund(uint256 amount) external override nonReentrant onlyRole(BENEFACTOR) {
        SafeERC20.safeTransfer(IERC20(token), msg.sender, amount);
    }

    /// @inheritdoc IMerkleVester
    function withdraw(
        uint256 withdrawalAmount,
        uint32 rootIndex,
        bytes memory decodableArgs,
        bytes32[] calldata proof,
        IPostClaimHandler postClaimHandler,
        bytes memory extraData
    )
        public
        payable
        override
        nonReentrant
    {
        if (_isCalendar(decodableArgs)) {
            _withdrawCalendar(withdrawalAmount, rootIndex, decodableArgs, proof, postClaimHandler, extraData);
        } else {
            _withdrawInterval(withdrawalAmount, rootIndex, decodableArgs, proof, postClaimHandler, extraData);
        }
    }

    /// @inheritdoc IMerkleVester
    function withdraw(
        uint256 withdrawalAmount,
        uint32 rootIndex,
        bytes memory decodableArgs,
        bytes32[] calldata proof
    )
        external
        payable
        override
    {
        withdraw(withdrawalAmount, rootIndex, decodableArgs, proof, IPostClaimHandler(address(0)), "");
    }

    /// @inheritdoc IMerkleVester
    function transferBeneficiaryAddress(
        address newBeneficiaryAddress,
        uint32 rootIndex,
        bytes memory decodableArgs,
        bytes32[] calldata proof
    )
        external
        nonReentrant
    {
        Allocation memory allocation = this.getLeafJustAllocationData(rootIndex, decodableArgs, proof);
        _checkOrSetOriginalBeneficiary(allocation);
        _transferBeneficiaryAddress(schedules[allocation.id], allocation, newBeneficiaryAddress);
    }

    /// @inheritdoc IMerkleVester
    function cancel(
        uint32 rootIndex,
        bytes memory decodableArgs,
        bytes32[] calldata proof
    )
        external
        override
        nonReentrant
        onlyRole(BENEFACTOR)
    {
        Allocation memory allocation = this.getLeafJustAllocationData(rootIndex, decodableArgs, proof);

        if (allocation.originalBeneficiary == address(0)) revert InvalidAllocation();
        if (!allocation.cancelable) revert NotCancellable();
        if (schedules[allocation.id].terminatedTimestamp != 0) revert AlreadyTerminated();

        _checkAlreadyFullyUnlocked(rootIndex, decodableArgs, proof);

        schedules[allocation.id].terminatedTimestamp = uint32(block.timestamp);

        emit ScheduleCanceled(allocation.id);
    }

    /// @inheritdoc IMerkleVester
    function revoke(
        uint32 rootIndex,
        bytes memory decodableArgs,
        bytes32[] calldata proof
    )
        external
        override
        nonReentrant
        onlyRole(BENEFACTOR)
    {
        Allocation memory allocation = this.getLeafJustAllocationData(rootIndex, decodableArgs, proof);

        if (allocation.originalBeneficiary == address(0)) revert InvalidAllocation();
        if (!allocation.revokable) revert NotRevokable();
        if (schedules[allocation.id].terminatedTimestamp != 0) revert AlreadyTerminated();

        // We use 1 as a sentinel value here to ensure that any withdrawals would not see anything vested and thus
        // withdrawable
        schedules[allocation.id].terminatedTimestamp = uint32(1);

        emit ScheduleRevoked(allocation.id);
    }

    /// @inheritdoc IMerkleVester
    function revokeAll() external nonReentrant onlyRole(BENEFACTOR) {
        SafeERC20.safeTransfer(IERC20(token), msg.sender, IERC20(token).balanceOf(address(this)));
    }

    /**
     * @notice Throws an exception if the allocation is fully unlocked
     *
     * @param rootIndex the index of the merkle root the allocation is in
     * @param decodableArgs the allocation data that constitutes the leaf to be decoded and verified
     * @param proof proof data of sibling leaves to verify the leaf is included in the root
     */
    function _checkAlreadyFullyUnlocked(
        uint32 rootIndex,
        bytes memory decodableArgs,
        bytes32[] calldata proof
    )
        internal
        view
    {
        if (_isCalendar(decodableArgs)) {
            (CalendarAllocation memory calendar, CalendarUnlockSchedule memory unlockSchedule) =
                this.getCalendarLeafAllocationData(rootIndex, decodableArgs, proof);
            if (block.timestamp >= unlockSchedule.unlockTimestamps[unlockSchedule.unlockTimestamps.length - 1]) {
                revert AlreadyFullyUnlocked();
            }
        } else {
            (IntervalAllocation memory interval, IntervalUnlockSchedule memory intervalUnlockSchedule) =
                this.getIntervalLeafAllocationData(rootIndex, decodableArgs, proof);
            uint32 finalUnlockTimestamp =
                _getPieceEndTime(intervalUnlockSchedule.pieces[intervalUnlockSchedule.pieces.length - 1]);
            if (block.timestamp >= finalUnlockTimestamp) revert AlreadyFullyUnlocked();
        }
    }

    /**
     * @notice Sets the original beneficiary, if not already set
     * @dev MerkleVester lazily sets the mutable schedule state, so we need to check if withdrawalAddress has not been
     * set, and if so set it to the immutable allocations originalBeneficiary address
     *
     * @param allocation allocation containing the original beneficiary
     */
    function _checkOrSetOriginalBeneficiary(Allocation memory allocation) internal {
        if (schedules[allocation.id].withdrawalAddress == address(0)) {
            schedules[allocation.id].withdrawalAddress = allocation.originalBeneficiary;
        }
    }

    /**
     * @notice Returns true, if the decodableArgs is calendar type
     *
     * @param decodableArgs decodable args to checks whether it is calendar type or not
     *
     * @return true, if decodable args is calendar type
     */
    function _isCalendar(bytes memory decodableArgs) internal pure returns (bool) {
        (string memory allocationType) = abi.decode(decodableArgs, (string));
        if (keccak256(abi.encodePacked(allocationType)) == keccak256("calendar")) {
            return true;
        } else if (keccak256(abi.encodePacked(allocationType)) == keccak256("interval")) {
            return false;
        } else {
            revert InvalidAllocationType();
        }
    }

    /**
     * @notice Withdraws vested funds from the contract to the beneficiary using Calendar type allocation
     *
     * @param withdrawalAmount optional amount to withdraw, specify 0 to withdraw all vested funds. If amount specified
     * is greater than vested amount this call will fail since that implies a incorrect intention
     * @param rootIndex the index of the merkle root the allocation is in
     * @param decodableArgs the allocation data that constitutes the leaf to be decoded and verified
     * @param proof proof data of sibling leaves to verify the leaf is included in the root
     * @param postClaimHandler the tokens will be automatically transferred to postClaimHandler contract, after which
     * the handlePostClaim will be automatically called
     * @param extraData extra data that will be passed to the post claim handler
     */
    function _withdrawCalendar(
        uint256 withdrawalAmount,
        uint32 rootIndex,
        bytes memory decodableArgs,
        bytes32[] calldata proof,
        IPostClaimHandler postClaimHandler,
        bytes memory extraData
    )
        internal
    {
        (CalendarAllocation memory calendar, CalendarUnlockSchedule memory unlockSchedule) =
            this.getCalendarLeafAllocationData(rootIndex, decodableArgs, proof);

        uint256 withdrawableAmount = _getVestedAmount(
            unlockSchedule.unlockTimestamps,
            unlockSchedule.unlockPercents,
            calendar.allocation.totalAllocation,
            schedules[calendar.allocation.id].terminatedTimestamp
        ) - schedules[calendar.allocation.id].withdrawn;

        uint256 contractBalance = IERC20(token).balanceOf(address(this));
        _checkOrSetOriginalBeneficiary(calendar.allocation);

        withdrawableAmount = Math.min(withdrawableAmount, contractBalance);
        _handleClaimFee(calendar.allocation.id);
        _withdrawToBeneficiary(
            calendar.allocation,
            schedules[calendar.allocation.id],
            withdrawableAmount,
            withdrawalAmount,
            postClaimHandler,
            extraData
        );
    }

    /**
     * @notice Withdraws vested funds from the contract to the beneficiary using Interval type allocation
     *
     * @param withdrawalAmount optional amount to withdraw, specify 0 to withdraw all vested funds. If amount specified
     * is greater than vested amount this call will fail since that implies a incorrect intention
     * @param rootIndex the index of the merkle root the allocation is in
     * @param decodableArgs the allocation data that constitutes the leaf to be decoded and verified
     * @param proof proof data of sibling leaves to verify the leaf is included in the root
     * @param postClaimHandler the tokens will be automatically transferred to postClaimHandler contract, after which
     * the handlePostClaim will be automatically called
     * @param extraData extra data that will be passed to the post claim handler
     */
    function _withdrawInterval(
        uint256 withdrawalAmount,
        uint32 rootIndex,
        bytes memory decodableArgs,
        bytes32[] calldata proof,
        IPostClaimHandler postClaimHandler,
        bytes memory extraData
    )
        internal
    {
        (IntervalAllocation memory interval, IntervalUnlockSchedule memory intervalUnlockSchedule) =
            this.getIntervalLeafAllocationData(rootIndex, decodableArgs, proof);

        uint256 withdrawableAmount =
            _getVestedAmount(interval, intervalUnlockSchedule) - schedules[interval.allocation.id].withdrawn;

        uint256 contractBalance = IERC20(token).balanceOf(address(this));

        _checkOrSetOriginalBeneficiary(interval.allocation);

        withdrawableAmount = Math.min(withdrawableAmount, contractBalance);
        _handleClaimFee(interval.allocation.id);
        _withdrawToBeneficiary(
            interval.allocation,
            schedules[interval.allocation.id],
            withdrawableAmount,
            withdrawalAmount,
            postClaimHandler,
            extraData
        );
    }

    /**
     * @notice Returns the claim fee for an allocation id
     *
     * @param allocationId the allocation id
     *
     * @return the claim fee
     */
    function getClaimFee(string memory allocationId) external returns (uint256) {
        if (shouldPayClaimFeeOnlyOnce && feeAlreadyPayed[allocationId]) {
            return 0;
        } else {
            return claimFee;
        }
    }

    /**
     * @notice Validates the fee parameters and transfers fee to fee collector
     *
     * @param allocationId the allocation id
     */
    function _handleClaimFee(string memory allocationId) private {
        uint256 calculatedClaimFee;
        if (shouldPayClaimFeeOnlyOnce) {
            if (!feeAlreadyPayed[allocationId] && claimFee != 0) {
                // if claimFee is 0, feeAlreadyPayed is not set to true
                feeAlreadyPayed[allocationId] = true;
                calculatedClaimFee = claimFee;
            }
        } else {
            calculatedClaimFee = claimFee;
        }

        if (msg.value != calculatedClaimFee) revert InvalidFeeFundsSent();

        if (calculatedClaimFee > 0) {
            if (feeCollector == address(0)) {
                revert InvalidFeeCollector();
            }
            SafeTransferLib.safeTransferETH(feeCollector, calculatedClaimFee);
        }
    }
}
