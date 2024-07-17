// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.25;

/// @notice Abstract contract containing all the events emitted.
abstract contract Events {
    /*//////////////////////////////////////////////////////////////////////////
                                      ERC-20
    //////////////////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 value);

    /*//////////////////////////////////////////////////////////////////////////
                            BAKERSSYNDICATE-REWARD-MANAGER
    //////////////////////////////////////////////////////////////////////////*/
    event PerformanceUpdated(uint256 reportingEpoch, uint256 rewardsPerEpoch);
    event RewardsClaimed(address indexed node, uint256 reward);

    /*//////////////////////////////////////////////////////////////////////////
                        BAKERSSYNDICATE-PERMISSIONED-NODE-REGISTRY
    //////////////////////////////////////////////////////////////////////////*/
    event NodeWhitelisted(address indexed node);
    event NodeRemovedFromWhitelist(address indexed node);
    event MaxNodesSet(uint8 maxNodes);

    /*//////////////////////////////////////////////////////////////////////////
                                BAKERSSYNDICATE-STAKING
    //////////////////////////////////////////////////////////////////////////*/
    event Staked(address indexed node, uint256 amount);
    event Unstaked(address indexed node, uint256 amount);
    event RewardsUpdated(address indexed node, uint256 indexed reportingEpoch, uint256 newRewards);
    event StakingAllowlistSet(bool isStakingAllowlist);
    event MinStakeAmountUpdated(uint256 oldMinStakeAmount, uint256 newMinStakeAmount);

    /*//////////////////////////////////////////////////////////////////////////
                                BAKERSSYNDICATE-MINT-MANAGER
    //////////////////////////////////////////////////////////////////////////*/
    event TokensMinted(address indexed account, uint256 amount);

    /*//////////////////////////////////////////////////////////////////////////
                                      GENERICS
    //////////////////////////////////////////////////////////////////////////*/

    event TransferAdmin(address indexed oldAdmin, address indexed newAdmin);
}
