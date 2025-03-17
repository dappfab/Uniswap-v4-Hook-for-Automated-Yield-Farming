// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

/**
 * @title IAavePool
 * @dev Interface for Aave V3 Pool
 */
interface IAavePool {
    /**
     * @dev Supplies an amount of asset to the protocol
     * @param asset The address of the asset to supply
     * @param amount The amount to supply
     * @param onBehalfOf The address that will receive the aTokens
     * @param referralCode The referral code
     */
    function supply(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;

    /**
     * @dev Withdraws an amount of asset from the protocol
     * @param asset The address of the asset to withdraw
     * @param amount The amount to withdraw
     * @param to The address that will receive the withdrawn assets
     * @return The final amount withdrawn
     */
    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256);
}