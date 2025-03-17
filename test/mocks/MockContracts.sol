// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockERC20
 * @dev Mock ERC20 token for testing
 */
contract MockERC20 is ERC20 {
    uint8 private _decimals;

    constructor(string memory name, string memory symbol, uint8 decimals_) ERC20(name, symbol) {
        _decimals = decimals_;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

/**
 * @title MockPoolManager
 * @dev Mock Uniswap v4 Pool Manager for testing
 */
contract MockPoolManager {
    // This is a simplified mock that just records calls
    address public lastCaller;
    bytes public lastCallData;

    function lock(bytes calldata data) external returns (bytes memory) {
        lastCaller = msg.sender;
        lastCallData = data;
        return abi.encode(true);
    }
}

/**
 * @title MockAavePool
 * @dev Mock Aave Pool for testing
 */
contract MockAavePool {
    mapping(address => address) public aTokens;
    mapping(address => uint256) public lastSupplyAmount;
    mapping(address => uint256) public lastWithdrawAmount;
    bool public supplyResponse;
    bool public withdrawResponse;

    function setAToken(address asset, address aToken) external {
        aTokens[asset] = aToken;
    }

    function setSupplyResponse(bool response) external {
        supplyResponse = response;
    }

    function setWithdrawResponse(bool response) external {
        withdrawResponse = response;
    }

    function supply(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external {
        lastSupplyAmount[asset] = amount;
        // Mock aToken minting would happen here
    }

    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256) {
        lastWithdrawAmount[asset] = amount;
        // Mock asset transfer would happen here
        return amount;
    }

    function getLastSupplyAmount(address asset) external view returns (uint256) {
        return lastSupplyAmount[asset];
    }

    function getLastWithdrawAmount(address asset) external view returns (uint256) {
        return lastWithdrawAmount[asset];
    }
}

/**
 * @title MockRewardsController
 * @dev Mock Aave Rewards Controller for testing
 */
contract MockRewardsController {
    mapping(address => uint256) public rewards;
    mapping(address => bool) public claimCalled;

    function setRewards(address asset, uint256 amount) external {
        rewards[asset] = amount;
    }

    function claimRewards(
        address[] calldata assets,
        uint256 amount,
        address to,
        bool incentivesController
    ) external returns (uint256) {
        uint256 totalClaimed = 0;
        
        for (uint i = 0; i < assets.length; i++) {
            claimCalled[assets[i]] = true;
            totalClaimed += rewards[assets[i]];
        }
        
        return totalClaimed;
    }
}