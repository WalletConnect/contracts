pragma solidity 0.8.25;

import { IPostClaimHandler } from "./IPostClaimHandler.sol";
import {
    Allocation,
    DistributionState,
    CalendarAllocation,
    CalendarUnlockSchedule,
    IntervalAllocation,
    IntervalUnlockSchedule,
    ZeroToken,
    ZeroBeneficiary,
    ClaimHandlerAlreadyWhitelisted,
    ClaimHandlerNotYetWhitelisted,
    InvalidWithdrawal,
    AmountZero,
    InsufficientFunds,
    DeflationaryTokensNotSupported,
    SameBeneficiaryAddress,
    NotTransferable,
    InvalidToken,
    PostClaimHandlerNotWhitelisted
} from "./AirlockTypes.sol";

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

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
    /// @dev the address for denoting whether direct claims are allowed
    address public constant DIRECT_CLAIM_ALLOWED = address(0);

    /**
     * @notice Constructor to create an IAirlockBase contract
     *
     * @param _token token address this vesting contract will distribute
     * @param _benefactor inital administator and benefactor of the contract
     * @param _directClaimAllowed true if _token can be directly sent to a user, false if _token can only be sent to an
     * integration contract
     */
    constructor(address _token, address _benefactor, bool _directClaimAllowed) {
        if (_token == address(0)) revert ZeroToken();
        if (_benefactor == address(0)) revert ZeroBeneficiary();
        token = _token;
        _grantRole(DEFAULT_ADMIN_ROLE, _benefactor); // The benefactor specified in the deploy can grant and revoke
            // benefactor roles using the AccessControl interface
        _grantRole(BENEFACTOR, _benefactor);
        _grantRole(POST_CLAIM_HANDLER_MANAGER, _benefactor);
        if (_directClaimAllowed) {
            postClaimHandlerWhitelist.add(DIRECT_CLAIM_ALLOWED);
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
        // If post claim handler is set to 0, it means the claim token has to be directly transferred to the beneficiary
        // without any interaction with an integration contract.
        if (address(postClaimHandler) == address(0)) {
            SafeERC20.safeTransfer(IERC20(token), withdrawalAddress, withdrawableAmount);
        } else {
            // Claim tokens have to be forwarded to an integration contract.
            SafeERC20.safeTransfer(IERC20(token), address(postClaimHandler), withdrawableAmount);

            // any error in the postClam handler will revert the entire transaction including the transfer above
            postClaimHandler.handlePostClaim(
                IERC20(token), withdrawableAmount, allocation.originalBeneficiary, withdrawalAddress, extraData
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
