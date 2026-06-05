// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { WalletConnectConfig } from "./WalletConnectConfig.sol";
import { StakingRewardDistributor } from "./StakingRewardDistributor.sol";

/// @title ClaimHelper
/// @notice Standalone periphery that lets users settle a staking-reward cursor that is more than
///         `MAX_REWARD_ITERATIONS` (52) weeks behind in a single transaction.
/// @dev The {StakingRewardDistributor} (SRD) caps each `_claim` at 52 weeks starting from
///      `weekCursorOf[user]`. A user who has not claimed for longer than ~1 year therefore needs to
///      call `claim` multiple times, each call advancing their cursor by up to 52 weeks. This helper
///      batches those passes into one call.
///
///      Because deployed contracts are never upgraded (except for exploits), this helper reuses the
///      EXISTING recipient hook on the SRD instead of any new privileged entrypoint:
///
///      1. The user calls `SRD.setRecipient(address(claimHelper))`. This authorizes the helper to call
///         `SRD.claim(user)` (the SRD allows `msg.sender == user || msg.sender == recipient[user]`) and
///         routes every payout to `getRecipient(user) == address(claimHelper)`.
///      2. The user (or anyone, see griefing note below) calls {claimN}. The helper loops `passes`
///         times over `SRD.claim(user)`, receives the full payout, and forwards it to `user` in the
///         same transaction.
///      3. The user optionally calls `SRD.setRecipient(address(0))` (or restores a previous recipient)
///         to stop routing future payouts through the helper.
///
///      Reentrancy: L2WCT is a plain ERC-20 with no transfer hooks, so the forward transfer cannot
///      re-enter. `nonReentrant` is nonetheless applied to match the repo convention (see {Airdrop}).
///
///      Stray tokens: the helper measures its OWN WCT balance delta across the claim loop and forwards
///      only that delta. Any pre-existing WCT balance (e.g. tokens accidentally sent to the helper) is
///      never swept to `user`.
///
///      Griefing: {claimN} is permissionless, but the payout destination is always `user`, so a caller
///      cannot redirect funds. The only effect of a third party calling it is advancing `user`'s cursor
///      and paying gas, which is harmless.
/// @author WalletConnect
contract ClaimHelper is ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice The WalletConnectConfig contract, source of truth for the SRD and L2WCT addresses.
    WalletConnectConfig public immutable config;

    /// @notice Emitted when {claimN} settles rewards for a user.
    /// @param user The user whose cursor was advanced and who received the payout.
    /// @param caller The address that invoked {claimN}.
    /// @param passes The number of `SRD.claim` passes executed.
    /// @param totalClaimed The total amount of WCT forwarded to `user`.
    event ClaimedN(address indexed user, address indexed caller, uint256 passes, uint256 totalClaimed);

    /// @notice Thrown when the config address provided to the constructor is the zero address.
    error InvalidConfig();

    /// @notice Thrown when `passes` is zero.
    error ZeroPasses();

    /// @param config_ The {WalletConnectConfig} contract. The SRD and L2WCT addresses are read from it,
    ///        so the helper always tracks the canonical deployments even if they are updated in config.
    constructor(WalletConnectConfig config_) {
        if (address(config_) == address(0)) revert InvalidConfig();
        config = config_;
    }

    /// @notice Settle up to `passes * 52` weeks of pending rewards for `user` in a single transaction
    ///         and forward the full payout to `user`.
    /// @dev The caller does NOT need to be `user`. The helper must be `user`'s recipient on the SRD,
    ///      i.e. `user` must have previously called `SRD.setRecipient(address(this))`. If the helper is
    ///      not the recipient, the underlying `SRD.claim` reverts with `UnauthorizedClaimer`.
    ///
    ///      Each pass advances `user`'s cursor by up to 52 weeks; extra passes beyond what is needed are
    ///      no-ops (the SRD returns 0 once the cursor reaches the current week). The payout is computed
    ///      as the helper's WCT balance delta across the whole loop, so only freshly claimed tokens are
    ///      forwarded and any stray pre-existing balance is left untouched.
    /// @param user The user whose rewards are being claimed.
    /// @param passes The number of `SRD.claim` passes to execute. Must be greater than zero.
    /// @return totalClaimed The total amount of WCT forwarded to `user`.
    function claimN(address user, uint256 passes) external nonReentrant returns (uint256 totalClaimed) {
        if (passes == 0) revert ZeroPasses();

        StakingRewardDistributor srd = StakingRewardDistributor(config.getStakingRewardDistributor());
        IERC20 l2wct = IERC20(config.getL2wct());

        // Measure delta, not absolute balance, so any stray pre-existing WCT is never forwarded.
        uint256 balanceBefore = l2wct.balanceOf(address(this));

        for (uint256 i = 0; i < passes; ++i) {
            srd.claim(user);
        }

        totalClaimed = l2wct.balanceOf(address(this)) - balanceBefore;

        if (totalClaimed != 0) {
            l2wct.safeTransfer(user, totalClaimed);
        }

        emit ClaimedN(user, msg.sender, passes, totalClaimed);
    }
}
