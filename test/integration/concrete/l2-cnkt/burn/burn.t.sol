// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { L2CNKT } from "src/L2CNKT.sol";
import { Integration_Test } from "test/integration/Integration.t.sol";

contract Burn_L2CNKT_Integration_Concrete_Test is Integration_Test {
    uint256 internal constant AMOUNT = 100;

    function setUp() public override {
        super.setUp();
        deployCoreConditionally();
        // Mint 100 CNKT to Alice
        vm.prank(address(mockBridge));
        l2cnkt.mint(users.alice, AMOUNT);
    }

    function test_RevertWhen_CallerNotBridge() external {
        vm.expectRevert(L2CNKT.OnlyBridge.selector);
        vm.prank(users.alice);
        l2cnkt.burn(users.alice, AMOUNT);
    }

    modifier whenCallerBridge() {
        _;
    }

    modifier whenTransferabilityOff() {
        _;
    }

    function test_RevertWhen_FromNotWhitelisted() external whenCallerBridge whenTransferabilityOff {
        vm.expectRevert(L2CNKT.TransferRestricted.selector);
        vm.startPrank(users.alice);
        mockBridge.bridgeERC20({
            localToken: address(cnkt),
            remoteToken: address(l2cnkt),
            amount: AMOUNT,
            minGasLimit: 100,
            extraData: ""
        });
    }

    modifier whenFromWhitelisted() {
        vm.prank(users.manager);
        l2cnkt.setAllowedFrom(users.alice, true);
        _;
    }

    modifier whenToWhitelisted() {
        vm.prank(users.manager);
        l2cnkt.setAllowedTo(address(0), true);
        _;
    }

    modifier whenTransferabilityOn() {
        vm.prank(users.admin);
        l2cnkt.disableTransferRestrictions();
        _;
    }

    function test_Burn_WhenFromWhitelisted() external whenCallerBridge whenTransferabilityOff whenFromWhitelisted {
        uint256 initialSupply = l2cnkt.totalSupply();
        uint256 initialBalance = l2cnkt.balanceOf(users.alice);

        vm.expectEmit(true, true, true, true);
        emit Transfer(users.alice, address(0), AMOUNT);
        vm.expectEmit(true, true, true, true);
        emit Burn(users.alice, AMOUNT);
        vm.expectEmit(true, true, true, true);
        emit ERC20BridgeInitiated(
            address(cnkt), address(l2cnkt), users.alice, users.alice, AMOUNT, abi.encodePacked(uint32(AMOUNT), "")
        );

        vm.startPrank(users.alice);
        mockBridge.bridgeERC20({
            localToken: address(cnkt),
            remoteToken: address(l2cnkt),
            amount: AMOUNT,
            minGasLimit: uint32(AMOUNT),
            extraData: ""
        });
        vm.stopPrank();

        assertEq(l2cnkt.balanceOf(users.alice), initialBalance - AMOUNT);
        assertEq(l2cnkt.totalSupply(), initialSupply - AMOUNT);
    }

    function test_Burn_WhenToWhitelisted() external whenCallerBridge whenTransferabilityOff whenToWhitelisted {
        uint256 initialSupply = l2cnkt.totalSupply();
        uint256 initialBalance = l2cnkt.balanceOf(users.alice);

        vm.expectEmit(true, true, true, true);
        emit Transfer(users.alice, address(0), AMOUNT);
        vm.expectEmit(true, true, true, true);
        emit Burn(users.alice, AMOUNT);

        vm.prank(address(mockBridge));
        l2cnkt.burn(users.alice, AMOUNT);

        assertEq(l2cnkt.balanceOf(users.alice), initialBalance - AMOUNT);
        assertEq(l2cnkt.totalSupply(), initialSupply - AMOUNT);
    }

    function test_RevertWhen_FromNotWhitelistedAndToNotWhitelisted() external whenCallerBridge whenTransferabilityOff {
        vm.expectRevert(L2CNKT.TransferRestricted.selector);
        vm.prank(address(mockBridge));
        l2cnkt.burn(users.alice, AMOUNT);
    }

    function test_Burn_WhenTransferabilityOn() external whenCallerBridge whenTransferabilityOn {
        uint256 initialSupply = l2cnkt.totalSupply();
        uint256 initialBalance = l2cnkt.balanceOf(users.alice);

        vm.expectEmit(true, true, true, true);
        emit Transfer(users.alice, address(0), AMOUNT);
        vm.expectEmit(true, true, true, true);
        emit Burn(users.alice, AMOUNT);

        vm.prank(address(mockBridge));
        l2cnkt.burn(users.alice, AMOUNT);

        assertEq(l2cnkt.balanceOf(users.alice), initialBalance - AMOUNT);
        assertEq(l2cnkt.totalSupply(), initialSupply - AMOUNT);
    }
}
