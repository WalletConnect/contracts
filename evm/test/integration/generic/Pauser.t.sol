// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { Base_Test } from "test/Base.t.sol";
import { Pauser } from "src/Pauser.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract Pauser_Test is Base_Test {
    function setUp() public override {
        super.setUp();
        deployCoreConditionally();
    }

    function testInitialization() public view {
        assertTrue(pauser.hasRole(pauser.DEFAULT_ADMIN_ROLE(), users.admin));
        assertTrue(pauser.hasRole(pauser.PAUSER_ROLE(), users.pauser));
        assertTrue(pauser.hasRole(pauser.UNPAUSER_ROLE(), users.admin));
    }

    function testInitializationRevertZeroAddress() public {
        Pauser pauserImpl = new Pauser();
        ERC1967Proxy proxy = new ERC1967Proxy(address(pauserImpl), "");
        Pauser pauserInstance = Pauser(address(proxy));

        Pauser.Init memory init = Pauser.Init({ admin: users.admin, pauser: address(0) });

        vm.expectRevert(Pauser.InvalidInput.selector);
        pauserInstance.initialize(init);
    }

    function testPauseStakeWeight() public {
        vm.startPrank(users.pauser);
        pauser.setIsStakeWeightPaused(true);
        assertTrue(pauser.isStakeWeightPaused());
        vm.stopPrank();

        vm.startPrank(users.admin);
        pauser.setIsStakeWeightPaused(false);
        assertFalse(pauser.isStakeWeightPaused());
        vm.stopPrank();
    }

    function testPauseSubmitOracleRecords() public {
        vm.startPrank(users.pauser);
        pauser.setIsSubmitOracleRecordsPaused(true);
        assertTrue(pauser.isSubmitOracleRecordsPaused());
        vm.stopPrank();

        vm.startPrank(users.admin);
        pauser.setIsSubmitOracleRecordsPaused(false);
        assertFalse(pauser.isSubmitOracleRecordsPaused());
        vm.stopPrank();
    }

    function testPauseLockedTokenStaker() public {
        vm.startPrank(users.pauser);
        pauser.setIsLockedTokenStakerPaused(true);
        assertTrue(pauser.isLockedTokenStakerPaused());
        vm.stopPrank();

        vm.startPrank(users.admin);
        pauser.setIsLockedTokenStakerPaused(false);
        assertFalse(pauser.isLockedTokenStakerPaused());
        vm.stopPrank();
    }

    function testPauseNodeRewardManager() public {
        vm.startPrank(users.pauser);
        pauser.setIsNodeRewardManagerPaused(true);
        assertTrue(pauser.isNodeRewardManagerPaused());
        vm.stopPrank();

        vm.startPrank(users.admin);
        pauser.setIsNodeRewardManagerPaused(false);
        assertFalse(pauser.isNodeRewardManagerPaused());
        vm.stopPrank();
    }

    function testPauseWalletRewardManager() public {
        vm.startPrank(users.pauser);
        pauser.setIsWalletRewardManagerPaused(true);
        assertTrue(pauser.isWalletRewardManagerPaused());
        vm.stopPrank();

        vm.startPrank(users.admin);
        pauser.setIsWalletRewardManagerPaused(false);
        assertFalse(pauser.isWalletRewardManagerPaused());
        vm.stopPrank();
    }

    function testPauseAll() public {
        vm.startPrank(users.pauser);
        pauser.pauseAll();
        assertTrue(pauser.isStakeWeightPaused());
        assertTrue(pauser.isSubmitOracleRecordsPaused());
        vm.stopPrank();
    }

    function testUnpauseAll() public {
        vm.startPrank(users.pauser);
        pauser.pauseAll();
        vm.stopPrank();

        vm.startPrank(users.admin);
        pauser.unpauseAll();
        assertFalse(pauser.isStakeWeightPaused());
        assertFalse(pauser.isSubmitOracleRecordsPaused());
        vm.stopPrank();
    }

    function testPauseRevertNotPauser() public {
        vm.startPrank(users.alice);

        vm.expectRevert(accessControlError(users.alice, pauser.PAUSER_ROLE()));
        pauser.setIsStakeWeightPaused(true);

        vm.expectRevert(accessControlError(users.alice, pauser.PAUSER_ROLE()));
        pauser.setIsSubmitOracleRecordsPaused(true);

        vm.expectRevert(accessControlError(users.alice, pauser.PAUSER_ROLE()));
        pauser.setIsLockedTokenStakerPaused(true);

        vm.expectRevert(accessControlError(users.alice, pauser.PAUSER_ROLE()));
        pauser.setIsNodeRewardManagerPaused(true);

        vm.expectRevert(accessControlError(users.alice, pauser.PAUSER_ROLE()));
        pauser.setIsWalletRewardManagerPaused(true);

        vm.expectRevert(accessControlError(users.alice, pauser.PAUSER_ROLE()));
        pauser.pauseAll();

        vm.stopPrank();
    }

    function testUnpauseRevertNotUnpauser() public {
        vm.startPrank(users.alice);

        vm.expectRevert(accessControlError(users.alice, pauser.UNPAUSER_ROLE()));
        pauser.setIsStakeWeightPaused(false);

        vm.expectRevert(accessControlError(users.alice, pauser.UNPAUSER_ROLE()));
        pauser.setIsSubmitOracleRecordsPaused(false);

        vm.expectRevert(accessControlError(users.alice, pauser.UNPAUSER_ROLE()));
        pauser.setIsLockedTokenStakerPaused(false);

        vm.expectRevert(accessControlError(users.alice, pauser.UNPAUSER_ROLE()));
        pauser.setIsNodeRewardManagerPaused(false);

        vm.expectRevert(accessControlError(users.alice, pauser.UNPAUSER_ROLE()));
        pauser.setIsWalletRewardManagerPaused(false);

        vm.expectRevert(accessControlError(users.alice, pauser.UNPAUSER_ROLE()));
        pauser.unpauseAll();

        vm.stopPrank();
    }

    function testEventEmissionOnPause() public {
        vm.startPrank(users.pauser);

        vm.expectEmit();
        emit FlagUpdated(pauser.isStakeWeightPaused.selector, true, "isStakeWeightPaused");
        pauser.setIsStakeWeightPaused(true);

        vm.expectEmit();
        emit FlagUpdated(pauser.isSubmitOracleRecordsPaused.selector, true, "isSubmitOracleRecordsPaused");
        pauser.setIsSubmitOracleRecordsPaused(true);

        vm.expectEmit();
        emit FlagUpdated(pauser.isLockedTokenStakerPaused.selector, true, "isLockedTokenStakerPaused");
        pauser.setIsLockedTokenStakerPaused(true);

        vm.expectEmit();
        emit FlagUpdated(pauser.isNodeRewardManagerPaused.selector, true, "isNodeRewardManagerPaused");
        pauser.setIsNodeRewardManagerPaused(true);

        vm.expectEmit();
        emit FlagUpdated(pauser.isWalletRewardManagerPaused.selector, true, "isWalletRewardManagerPaused");
        pauser.setIsWalletRewardManagerPaused(true);

        vm.stopPrank();
    }

    // Helper for access control error message
    function accessControlError(address account, bytes32 role) internal pure returns (bytes memory) {
        return abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", account, role);
    }
}
