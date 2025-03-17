// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {BaseHook} from "v4-periphery/BaseHook.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {CurrencyLibrary} from "v4-core/types/Currency.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IAavePool} from "./interfaces/IAavePool.sol";
import {IRewardsController} from "./interfaces/IRewardsController.sol";

/**
 * @title YieldOptimizerHook
 * @dev A Uniswap v4 hook that optimizes yield by staking idle liquidity in Aave or similar protocols
 */
contract YieldOptimizerHook is BaseHook {
    using SafeERC20 for IERC20;
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;

    // Aave v3 pool contract
    IAavePool public immutable aavePool;
    // Aave rewards controller
    IRewardsController public immutable rewardsController;
    
    // Mapping to track if a token is supported for yield optimization
    mapping(address => bool) public supportedTokens;
    
    // Mapping to store aToken addresses for each token
    mapping(address => address) public aTokens;
    
    // Target reserve percentage to keep in the pool (e.g., 20% = 2000)
    // This is the percentage of tokens that will not be staked
    uint256 public reservePercentage = 2000; // 20% by default
    
    // Max basis points (100%)
    uint256 public constant MAX_BPS = 10000;

    // Events
    event TokensStaked(address indexed token, uint256 amount);
    event TokensWithdrawn(address indexed token, uint256 amount);
    event ReservePercentageUpdated(uint256 newPercentage);
    event SupportedTokenAdded(address indexed token, address indexed aToken);
    event SupportedTokenRemoved(address indexed token);
    event YieldHarvested(address indexed token, uint256 amount);

    /**
     * @dev Constructor
     * @param _poolManager The Uniswap v4 pool manager
     * @param _aavePool The Aave lending pool address
     * @param _rewardsController The Aave rewards controller address
     */
    constructor(
        IPoolManager _poolManager,
        IAavePool _aavePool,
        IRewardsController _rewardsController
    ) BaseHook(_poolManager) {
        aavePool = _aavePool;
        rewardsController = _rewardsController;
    }

    /**
     * @dev Add a token to the supported tokens list
     * @param token The token address to add
     * @param aToken The corresponding aToken address
     */
    function addSupportedToken(address token, address aToken) external {
        // Only owner can add supported tokens
        // Add access control here
        
        supportedTokens[token] = true;
        aTokens[token] = aToken;
        
        // Approve the Aave pool to spend this token
        IERC20(token).safeApprove(address(aavePool), type(uint256).max);
        
        emit SupportedTokenAdded(token, aToken);
    }

    /**
     * @dev Remove a token from the supported tokens list
     * @param token The token address to remove
     */
    function removeSupportedToken(address token) external {
        // Only owner can remove supported tokens
        // Add access control here
        
        supportedTokens[token] = false;
        
        // Revoke approval
        IERC20(token).safeApprove(address(aavePool), 0);
        
        emit SupportedTokenRemoved(token);
    }

    /**
     * @dev Set the reserve percentage
     * @param newReservePercentage The new reserve percentage (in basis points)
     */
    function setReservePercentage(uint256 newReservePercentage) external {
        // Only owner can update reserve percentage
        // Add access control here
        
        require(newReservePercentage <= MAX_BPS, "Reserve percentage exceeds maximum");
        reservePercentage = newReservePercentage;
        
        emit ReservePercentageUpdated(newReservePercentage);
    }

    /**
     * @dev Stake available tokens in Aave
     * @param token The token address to stake
     */
    function stakeAvailableTokens(address token) public {
        require(supportedTokens[token], "Token not supported");
        
        // Get current balance
        uint256 balance = IERC20(token).balanceOf(address(this));
        
        // Calculate how much to keep as reserve
        uint256 reserveAmount = (balance * reservePercentage) / MAX_BPS;
        
        // Calculate how much to stake
        uint256 amountToStake = balance > reserveAmount ? balance - reserveAmount : 0;
        
        if (amountToStake > 0) {
            // Supply tokens to Aave
            aavePool.supply(token, amountToStake, address(this), 0);
            emit TokensStaked(token, amountToStake);
        }
    }

    /**
     * @dev Withdraw tokens from Aave when needed
     * @param token The token address to withdraw
     * @param amount The amount to withdraw
     */
    function withdrawFromYieldPlatform(address token, uint256 amount) internal {
        require(supportedTokens[token], "Token not supported");
        
        // Get current balance
        uint256 balance = IERC20(token).balanceOf(address(this));
        
        // If we don't have enough, withdraw from Aave
        if (balance < amount) {
            uint256 amountToWithdraw = amount - balance;
            
            // Withdraw from Aave
            aavePool.withdraw(token, amountToWithdraw, address(this));
            
            emit TokensWithdrawn(token, amountToWithdraw);
        }
    }

    /**
     * @dev Harvest yields from staked tokens
     * @param token The token address to harvest yields from
     */
    function harvestYield(address token) external {
        require(supportedTokens[token], "Token not supported");
        
        // Get the aToken address
        address aToken = aTokens[token];
        
        // Claim rewards if any
        address[] memory assets = new address[](1);
        assets[0] = aToken;
        
        rewardsController.claimRewards(assets, type(uint256).max, address(this), false);
        
        // Calculate yield (aToken balance - principal)
        uint256 aTokenBalance = IERC20(aToken).balanceOf(address(this));
        
        // For simplicity, we're not tracking principal here
        // In a real implementation, you'd need to track how much was deposited
        
        emit YieldHarvested(token, aTokenBalance);
    }

    /**
     * @dev Calculate the amount of tokens that can be safely withdrawn
     * @param token The token address
     * @return The amount that can be safely withdrawn
     */
    function calculateWithdrawableAmount(address token) public view returns (uint256) {
        uint256 balance = IERC20(token).balanceOf(address(this));
        
        // If this token is supported for yield optimization
        if (supportedTokens[token]) {
            // Add the aToken balance (what's staked in Aave)
            address aToken = aTokens[token];
            balance += IERC20(aToken).balanceOf(address(this));
        }
        
        return balance;
    }

    // Override BaseHook's beforeSwap hook
    function beforeSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        bytes calldata
    ) external override returns (bytes4) {
        // Check if we need to withdraw tokens for this swap
        address tokenIn = params.zeroForOne ? address(key.currency0) : address(key.currency1);
        address tokenOut = params.zeroForOne ? address(key.currency1) : address(key.currency0);
        
        // If tokenOut is a supported token and we need to withdraw it
        if (supportedTokens[tokenOut]) {
            // Calculate how much we need to withdraw
            // This is a simplified version, in reality you'd need to calculate based on the swap params
            uint256 amountOut = params.amountSpecified > 0 ? uint256(params.amountSpecified) : 0;
            
            if (amountOut > 0) {
                withdrawFromYieldPlatform(tokenOut, amountOut);
            }
        }
        
        return BaseHook.beforeSwap.selector;
    }

    // Override BaseHook's afterSwap hook
    function afterSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata
    ) external override returns (bytes4) {
        // Get the tokens involved in the swap
        address token0 = address(key.currency0);
        address token1 = address(key.currency1);
        
        // Stake any excess tokens
        if (supportedTokens[token0]) {
            stakeAvailableTokens(token0);
        }
        
        if (supportedTokens[token1]) {
            stakeAvailableTokens(token1);
        }
        
        return BaseHook.afterSwap.selector;
    }

    // Override other BaseHook functions (required by the interface)
    function beforeInitialize(
        address sender,
        PoolKey calldata key,
        uint160 sqrtPriceX96,
        bytes calldata
    ) external override returns (bytes4) {
        return BaseHook.beforeInitialize.selector;
    }

    function afterInitialize(
        address sender,
        PoolKey calldata key,
        uint160 sqrtPriceX96,
        int24 tick,
        bytes calldata
    ) external override returns (bytes4) {
        return BaseHook.afterInitialize.selector;
    }

    function beforeModifyPosition(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyPositionParams calldata params,
        bytes calldata
    ) external override returns (bytes4) {
        return BaseHook.beforeModifyPosition.selector;
    }

    function afterModifyPosition(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyPositionParams calldata params,
        BalanceDelta delta,
        bytes calldata
    ) external override returns (bytes4) {
        // After liquidity is added, stake excess tokens
        address token0 = address(key.currency0);
        address token1 = address(key.currency1);
        
        if (supportedTokens[token0]) {
            stakeAvailableTokens(token0);
        }
        
        if (supportedTokens[token1]) {
            stakeAvailableTokens(token1);
        }
        
        return BaseHook.afterModifyPosition.selector;
    }

    function beforeDonate(
        address sender,
        PoolKey calldata key,
        uint256 amount0,
        uint256 amount1,
        bytes calldata
    ) external override returns (bytes4) {
        return BaseHook.beforeDonate.selector;
    }

    function afterDonate(
        address sender,
        PoolKey calldata key,
        uint256 amount0,
        uint256 amount1,
        bytes calldata
    ) external override returns (bytes4) {
        return BaseHook.afterDonate.selector;
    }
}