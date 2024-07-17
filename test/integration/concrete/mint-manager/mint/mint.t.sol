// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { MintManager } from "src/MintManager.sol";
import { BRR } from "src/BRR.sol";
import { Integration_Test } from "test/integration/Integration.t.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC20Votes } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

contract Mint_MintManager_Integration_Concrete_Test is Integration_Test {
    MintManager internal mintManager;

    function setUp() public override {
        super.setUp();
        vm.startPrank(users.admin);
        mintManager = new MintManager(users.admin, address(brr));
        brr.transferOwnership(address(mintManager));
        vm.stopPrank();

        vm.label(address(mintManager), "MintManager");
    }

    function test_RevertWhen_CallerIsNotOwner() external {
        vm.startPrank(users.attacker);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.attacker));
        mintManager.mint(users.attacker, 1);
        vm.stopPrank();
    }

    modifier whenCallerIsOwner() {
        vm.startPrank(users.admin);
        _;
    }

    function test_RevertGiven_MintPermittedAfterIsInFuture() external whenCallerIsOwner {
        // First mint to set mintPermittedAfter
        mintManager.mint(users.admin, 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                MintManager.MintingNotPermittedYet.selector, block.timestamp, mintManager.mintPermittedAfter()
            )
        );
        mintManager.mint(users.admin, 1);
    }

    modifier givenMintPermittedAfterIsZero() {
        _;
    }

    function test_RevertWhen_AmountExceedsMaxSupply() external whenCallerIsOwner givenMintPermittedAfterIsZero {
        uint256 maxSupplyForERC20Votes = BRR_MAX_SUPPLY;
        uint256 mintAmount = maxSupplyForERC20Votes + 1;
        vm.expectRevert(
            abi.encodeWithSelector(ERC20Votes.ERC20ExceededSafeSupply.selector, mintAmount, maxSupplyForERC20Votes)
        );
        mintManager.mint(users.admin, mintAmount);
    }

    function test_Mint_WhenAmountIsLTEMaxSupply() external whenCallerIsOwner givenMintPermittedAfterIsZero {
        uint256 maxSupplyForERC20Votes = BRR_MAX_SUPPLY;
        uint256 mintAmount = maxSupplyForERC20Votes;
        uint256 initialSupply = brr.totalSupply();

        uint256 initialBalance = brr.balanceOf(users.admin);

        vm.expectEmit(true, true, true, true);
        emit TokensMinted(users.admin, mintAmount);

        mintManager.mint(users.admin, mintAmount);

        assertEq(
            brr.balanceOf(users.admin),
            initialBalance + mintAmount,
            "users.admin balance should increase by mint amount"
        );
        assertEq(brr.totalSupply(), initialSupply + mintAmount, "Total supply should increase by mint amount");
        assertEq(
            mintManager.mintPermittedAfter(),
            block.timestamp + mintManager.MINT_PERIOD(),
            "mintPermittedAfter should be updated"
        );
    }

    modifier givenMintPermittedAfterIsPast() {
        // Needs a mint to set mintPermittedAfter
        mintManager.mint(users.admin, 1);
        // Warp to after the mint period if necessary
        if (mintManager.mintPermittedAfter() > 0) {
            vm.warp(mintManager.mintPermittedAfter() + 1);
        }
        _;
    }

    function test_RevertWhen_AmountExceedsMintCap() external whenCallerIsOwner givenMintPermittedAfterIsPast {
        uint256 initialSupply = brr.totalSupply();
        uint256 mintCap = (initialSupply * mintManager.MINT_CAP()) / mintManager.DENOMINATOR();
        uint256 mintAmount = mintCap + 1;

        vm.expectRevert(abi.encodeWithSelector(MintManager.MintAmountExceedsCap.selector, mintAmount, mintCap));
        mintManager.mint(users.admin, mintAmount);
    }

    function test_Mint_WhenAmountIsWithinMintCap() external whenCallerIsOwner givenMintPermittedAfterIsPast {
        uint256 initialSupply = brr.totalSupply();
        uint256 mintAmount = (initialSupply * mintManager.MINT_CAP()) / mintManager.DENOMINATOR();

        uint256 initialBalance = brr.balanceOf(users.admin);

        vm.expectEmit(true, true, true, true);
        emit TokensMinted(users.admin, mintAmount);

        mintManager.mint(users.admin, mintAmount);

        assertEq(
            brr.balanceOf(users.admin),
            initialBalance + mintAmount,
            "users.admin balance should increase by mint amount"
        );
        assertEq(brr.totalSupply(), initialSupply + mintAmount, "Total supply should increase by mint amount");
        assertEq(
            mintManager.mintPermittedAfter(),
            block.timestamp + mintManager.MINT_PERIOD(),
            "mintPermittedAfter should be updated"
        );
    }
}
