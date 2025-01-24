// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.8.25;

import "./eip712/EIP712MetaTransaction.sol";

/**
 * @title DelegateRegistry
 * @author Modified from Gnosis DelegateRegistry (https://github.com/gnosis/delegate-registry)
 * @notice A registry that enables users to delegate permissions to other addresses with meta-transaction support
 * @dev Integrates Biconomy's EIP712MetaTransaction (https://github.com/bcnmy/metatx-standard)
 *      for gasless transactions support
 */
contract DelegateRegistry is EIP712MetaTransaction {
    // The first key is the delegator and the second key a id.
    // The value is the address of the delegate
    mapping(address => mapping(bytes32 => address)) public delegation;

    constructor(string memory name, string memory version) EIP712MetaTransaction(name, version) { }

    // Using these events it is possible to process the events to build up reverse lookups.
    // The indeces allow it to be very partial about how to build this lookup (e.g. only for a specific delegate).
    event SetDelegate(address indexed delegator, bytes32 indexed id, address indexed delegate);
    event ClearDelegate(address indexed delegator, bytes32 indexed id, address indexed delegate);

    /// @notice Sets a delegate for the sender and a specific id
    /// @dev The combination of sender and id can be seen as a unique key
    ///      Supports meta-transactions through msgSender()
    /// @param id Id for which the delegate should be set
    /// @param delegate Address of the delegate
    function setDelegate(bytes32 id, address delegate) public {
        require(delegate != msgSender(), "Can't delegate to self");
        require(delegate != address(0), "Can't delegate to 0x0");
        address currentDelegate = delegation[msgSender()][id];
        require(delegate != currentDelegate, "Already delegated to this address");

        // Update delegation mapping
        delegation[msgSender()][id] = delegate;

        if (currentDelegate != address(0)) {
            emit ClearDelegate(msgSender(), id, currentDelegate);
        }

        emit SetDelegate(msgSender(), id, delegate);
    }

    /// @notice Clears a delegate for the sender and a specific id
    /// @dev The combination of sender and id can be seen as a unique key
    ///      Supports meta-transactions through msgSender()
    /// @param id Id for which the delegate should be cleared
    function clearDelegate(bytes32 id) public {
        address currentDelegate = delegation[msgSender()][id];
        require(currentDelegate != address(0), "No delegate set");

        // update delegation mapping
        delegation[msgSender()][id] = address(0);

        emit ClearDelegate(msgSender(), id, currentDelegate);
    }
}
