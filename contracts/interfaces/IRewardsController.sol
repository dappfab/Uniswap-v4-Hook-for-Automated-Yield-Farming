// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

/**
 * @title IRewardsController
 * @dev Interface for Aave V3 Rewards Controller
 */
interface IRewardsController {
    /**
     * @dev Claims rewards for a list of assets
     * @param assets The list of assets to claim rewards for
     * @param amount The amount of rewards to claim
     * @param to The address that will receive the rewards
     * @param incentivesController The address of the incentives controller
     */
    function claimRewards(
        address[] calldata assets,
        uint256 amount,
        address to,
        bool incentivesController
    ) external returns (uint256);
}