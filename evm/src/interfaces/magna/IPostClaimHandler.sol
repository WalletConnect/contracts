pragma solidity 0.8.25;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

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
     * @param extraData Any abi encoded extra data that is necessary for the custom action. For example in case of a
     * custom staking action, the user could state his
     *                  staking preference by providing extraData.
     */
    function handlePostClaim(
        IERC20 claimToken,
        uint256 amount,
        address originalBeneficiary,
        address withdrawalAddress,
        bytes memory extraData
    )
        external;
}
