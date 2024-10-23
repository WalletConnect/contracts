// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { L2WCT } from "src/L2WCT.sol";
import { Integration_Test } from "test/integration/Integration.t.sol";

contract Burn_L2WCT_Integration_Concrete_Test is Integration_Test {
    uint256 internal constant AMOUNT = 100;

    function setUp() public override {
        super.setUp();
        // Mint 100 WCT to Alice
        vm.prank(address(mockBridge));
        l2wct.mint(users.alice, AMOUNT);
    }

    function test_RevertWhen_CallerNotBridge() external {
        vm.expectRevert(L2WCT.OnlyBridge.selector);
        vm.prank(users.alice);
        l2wct.burn(users.alice, AMOUNT);
    }

    modifier whenCallerBridge() {
        _;
    }

    modifier whenTransferabilityOff() {
        _;
    }

    function test_RevertWhen_FromNotWhitelisted() external whenCallerBridge whenTransferabilityOff {
        vm.expectRevert(L2WCT.TransferRestricted.selector);
        vm.startPrank(users.alice);
        mockBridge.bridgeERC20({
            localToken: address(wct),
            remoteToken: address(l2wct),
            amount: AMOUNT,
            minGasLimit: 100,
            extraData: ""
        });
    }

    modifier whenFromWhitelisted() {
        vm.prank(users.manager);
        l2wct.setAllowedFrom(users.alice, true);
        _;
    }

    modifier whenToWhitelisted() {
        vm.prank(users.manager);
        l2wct.setAllowedTo(address(0), true);
        _;
    }

    modifier whenTransferabilityOn() {
        vm.prank(users.admin);
        l2wct.disableTransferRestrictions();
        _;
    }

    function test_Burn_WhenFromWhitelisted() external whenCallerBridge whenTransferabilityOff whenFromWhitelisted {
        uint256 initialSupply = l2wct.totalSupply();
        uint256 initialBalance = l2wct.balanceOf(users.alice);

        vm.expectEmit(true, true, true, true);
        emit Transfer(users.alice, address(0), AMOUNT);
        vm.expectEmit(true, true, true, true);
        emit Burn(users.alice, AMOUNT);
        vm.expectEmit(true, true, true, true);
        emit ERC20BridgeInitiated(
            address(wct), address(l2wct), users.alice, users.alice, AMOUNT, abi.encodePacked(uint32(AMOUNT), "")
        );

        vm.startPrank(users.alice);
        mockBridge.bridgeERC20({
            localToken: address(wct),
            remoteToken: address(l2wct),
            amount: AMOUNT,
            minGasLimit: uint32(AMOUNT),
            extraData: ""
        });
        vm.stopPrank();

        assertEq(l2wct.balanceOf(users.alice), initialBalance - AMOUNT);
        assertEq(l2wct.totalSupply(), initialSupply - AMOUNT);
    }

    function test_Burn_WhenToWhitelisted() external whenCallerBridge whenTransferabilityOff whenToWhitelisted {
        uint256 initialSupply = l2wct.totalSupply();
        uint256 initialBalance = l2wct.balanceOf(users.alice);

        vm.expectEmit(true, true, true, true);
        emit Transfer(users.alice, address(0), AMOUNT);
        vm.expectEmit(true, true, true, true);
        emit Burn(users.alice, AMOUNT);

        vm.prank(address(mockBridge));
        l2wct.burn(users.alice, AMOUNT);

        assertEq(l2wct.balanceOf(users.alice), initialBalance - AMOUNT);
        assertEq(l2wct.totalSupply(), initialSupply - AMOUNT);
    }

    function test_RevertWhen_FromNotWhitelistedAndToNotWhitelisted() external whenCallerBridge whenTransferabilityOff {
        vm.expectRevert(L2WCT.TransferRestricted.selector);
        vm.prank(address(mockBridge));
        l2wct.burn(users.alice, AMOUNT);
    }

    function test_Burn_WhenTransferabilityOn() external whenCallerBridge whenTransferabilityOn {
        uint256 initialSupply = l2wct.totalSupply();
        uint256 initialBalance = l2wct.balanceOf(users.alice);

        vm.expectEmit(true, true, true, true);
        emit Transfer(users.alice, address(0), AMOUNT);
        vm.expectEmit(true, true, true, true);
        emit Burn(users.alice, AMOUNT);

        vm.prank(address(mockBridge));
        l2wct.burn(users.alice, AMOUNT);

        assertEq(l2wct.balanceOf(users.alice), initialBalance - AMOUNT);
        assertEq(l2wct.totalSupply(), initialSupply - AMOUNT);
    }
}
