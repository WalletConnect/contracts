// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { ClaimHelper } from "src/ClaimHelper.sol";
import { StakingRewardDistributor } from "src/StakingRewardDistributor.sol";
import { StakeWeight_Integration_Shared_Test } from "../../../shared/StakeWeight.t.sol";

/// @notice Integration tests for {ClaimHelper.claimN}.
/// @dev The helper relies on the SRD recipient hook: the user calls `SRD.setRecipient(helper)`, which
///      both authorizes the helper to claim on their behalf and routes payouts to the helper, which
///      then forwards them to the user.
contract ClaimN_ClaimHelper_Integration_Concrete_Test is StakeWeight_Integration_Shared_Test {
    /// @dev Mirror of the event defined in {ClaimHelper}.
    event ClaimedN(address indexed user, address indexed caller, uint256 passes, uint256 totalClaimed);

    ClaimHelper internal claimHelper;

    /// @dev Per-week reward injected for the multi-pass scenario. The locker is the sole staker, so
    ///      they receive the full weekly amount each week.
    uint256 internal constant WEEKLY_REWARD = 1000 ether;

    function setUp() public override {
        super.setUp();
        // setRecipient and token transfers require transfer restrictions to be disabled.
        disableTransferRestrictions();
        claimHelper = new ClaimHelper(walletConnectConfig);
        // Align the SRD week cursor to the current week, mirroring the existing SRD claim tests.
        vm.warp(_timestampToFloorWeek(block.timestamp + 1 weeks));
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Injects `WEEKLY_REWARD` into each of the next `numWeeks` weeks starting from the current week.
    function _injectWeeklyRewards(uint256 numWeeks) internal {
        uint256 currentWeek = _timestampToFloorWeek(block.timestamp);
        uint256 total = WEEKLY_REWARD * numWeeks;

        deal(address(l2wct), users.admin, total);
        vm.startPrank(users.admin);
        l2wct.approve(address(stakingRewardDistributor), total);
        for (uint256 i = 0; i < numWeeks; i++) {
            stakingRewardDistributor.injectReward({ timestamp: currentWeek + (i * 1 weeks), amount: WEEKLY_REWARD });
        }
        vm.stopPrank();
    }

    /// @dev Creates a permanent lock so the user's weight (and thus weekly reward share) stays constant.
    function _createPermanentLock(address user, uint256 amount) internal {
        deal(address(l2wct), user, amount);
        vm.startPrank(user);
        l2wct.approve(address(stakeWeight), amount);
        stakeWeight.createPermanentLock(amount, 52 weeks);
        vm.stopPrank();
    }

    modifier asRecipient(address user) {
        vm.prank(user);
        stakingRewardDistributor.setRecipient(address(claimHelper));
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     REVERTS
    //////////////////////////////////////////////////////////////////////////*/

    function test_RevertWhen_PassesIsZero() external {
        vm.expectRevert(ClaimHelper.ZeroPasses.selector);
        claimHelper.claimN(users.alice, 0);
    }

    modifier whenPassesIsGreaterThanZero() {
        _;
    }

    function test_RevertWhen_HelperIsNotRecipient() external whenPassesIsGreaterThanZero {
        // Alice has a lock and pending rewards but never set the helper as her recipient.
        _createPermanentLock(users.alice, 1000 ether);
        _injectWeeklyRewards(1);
        _mineBlocks(defaults.ONE_WEEK_IN_BLOCKS());

        // SRD.claim reverts because msg.sender (the helper) is neither the user nor the user's recipient.
        vm.expectRevert(StakingRewardDistributor.UnauthorizedClaimer.selector);
        claimHelper.claimN(users.alice, 1);
    }

    modifier whenHelperIsRecipient() {
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                  MULTI-PASS
    //////////////////////////////////////////////////////////////////////////*/

    function test_ClaimN_StaleCursorMoreThan52WeeksBehind()
        external
        whenPassesIsGreaterThanZero
        whenHelperIsRecipient
        asRecipient(users.alice)
    {
        uint256 lockAmount = 1000 ether;
        _createPermanentLock(users.alice, lockAmount);

        // Inject rewards for 104 weeks (2x the 52-week per-call cap), then advance past all of them so
        // the entire window is claimable. Alice never claims, so her cursor is stranded >52 weeks back.
        uint256 numWeeks = 104;
        _injectWeeklyRewards(numWeeks);
        _mineBlocks(defaults.ONE_WEEK_IN_BLOCKS() * (numWeeks + 1));

        uint256 expectedTotal = WEEKLY_REWARD * numWeeks;

        uint256 aliceBefore = l2wct.balanceOf(users.alice);

        // Two passes are required: one call only settles up to 52 weeks.
        vm.expectEmit(true, true, true, true);
        emit ClaimedN(users.alice, address(this), 2, expectedTotal);
        uint256 totalClaimed = claimHelper.claimN(users.alice, 2);

        assertEq(totalClaimed, expectedTotal, "should claim the full 104 weeks across 2 passes");
        assertEq(
            l2wct.balanceOf(users.alice) - aliceBefore, expectedTotal, "user balance should increase by full pending"
        );
        assertEq(l2wct.balanceOf(address(claimHelper)), 0, "helper should retain nothing");
    }

    function test_ClaimN_StaleCursor_OnePassIsNotEnough()
        external
        whenPassesIsGreaterThanZero
        whenHelperIsRecipient
        asRecipient(users.alice)
    {
        _createPermanentLock(users.alice, 1000 ether);

        uint256 numWeeks = 104;
        _injectWeeklyRewards(numWeeks);
        _mineBlocks(defaults.ONE_WEEK_IN_BLOCKS() * (numWeeks + 1));

        // A single pass settles at most 52 weeks, leaving the rest pending.
        uint256 onePass = claimHelper.claimN(users.alice, 1);
        assertEq(onePass, WEEKLY_REWARD * 52, "single pass should settle exactly 52 weeks");

        // A second invocation settles the remaining 52 weeks.
        uint256 secondPass = claimHelper.claimN(users.alice, 1);
        assertEq(secondPass, WEEKLY_REWARD * 52, "second pass should settle the remaining 52 weeks");
    }

    /*//////////////////////////////////////////////////////////////////////////
                              SINGLE-PASS EQUIVALENCE
    //////////////////////////////////////////////////////////////////////////*/

    function test_ClaimN_SinglePassMatchesDirectClaim() external whenPassesIsGreaterThanZero whenHelperIsRecipient {
        // Two identical users: alice claims directly, bob claims via the helper with a single pass.
        _createPermanentLock(users.alice, 1000 ether);
        _createPermanentLock(users.bob, 1000 ether);
        _injectWeeklyRewards(1);
        _mineBlocks(defaults.ONE_WEEK_IN_BLOCKS());

        // Bob routes through the helper.
        vm.prank(users.bob);
        stakingRewardDistributor.setRecipient(address(claimHelper));

        vm.prank(users.alice);
        uint256 aliceDirect = stakingRewardDistributor.claim(users.alice);
        uint256 bobViaHelper = claimHelper.claimN(users.bob, 1);

        assertEq(bobViaHelper, aliceDirect, "single-pass claimN should equal a direct claim");
        assertEq(l2wct.balanceOf(users.bob), bobViaHelper, "bob should receive his rewards");
        assertEq(l2wct.balanceOf(address(claimHelper)), 0, "helper should retain nothing");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                DELTA ISOLATION
    //////////////////////////////////////////////////////////////////////////*/

    function test_ClaimN_DoesNotForwardStrayBalance()
        external
        whenPassesIsGreaterThanZero
        whenHelperIsRecipient
        asRecipient(users.alice)
    {
        _createPermanentLock(users.alice, 1000 ether);
        _injectWeeklyRewards(1);
        _mineBlocks(defaults.ONE_WEEK_IN_BLOCKS());

        // Pre-fund the helper with stray WCT that must NOT be forwarded to alice.
        uint256 stray = 777 ether;
        deal(address(l2wct), address(claimHelper), stray);

        uint256 aliceBefore = l2wct.balanceOf(users.alice);
        uint256 totalClaimed = claimHelper.claimN(users.alice, 1);

        assertEq(totalClaimed, WEEKLY_REWARD, "should claim only one week of rewards");
        assertEq(l2wct.balanceOf(users.alice) - aliceBefore, WEEKLY_REWARD, "stray balance must not be forwarded");
        assertEq(l2wct.balanceOf(address(claimHelper)), stray, "stray balance must remain in the helper");
    }
}
