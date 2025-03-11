// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

contract SimpleAccount {
    function executeTx(
        address target,
        bytes calldata data,
        bool isDelegateCall
    )
        external
        payable
        returns (bytes memory)
    {
        (bool success, bytes memory result) =
            isDelegateCall ? target.delegatecall(data) : target.call{ value: msg.value }(data);
        if (!success) {
            // Forward the raw revert data which preserves custom errors
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
        return result;
    }
}
