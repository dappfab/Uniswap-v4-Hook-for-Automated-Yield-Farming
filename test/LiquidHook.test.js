const { expect } = require("chai");
const { ethers } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

describe("LiquidHook", function () {
    // Bu fonksiyonu bir kez çalıştırıp, her test için tekrar kullanacağız
    async function deployFixture() {
        // Get signers
        const [owner, user1, user2] = await ethers.getSigners();

        // Deploy mock tokens
        const MockToken = await ethers.getContractFactory("MockERC20");
        const usdc = await MockToken.deploy("USD Coin", "USDC", 6);
        const dai = await MockToken.deploy("Dai Stablecoin", "DAI", 18);
        const aUsdc = await MockToken.deploy("Aave USDC", "aUSDC", 6);
        const aDai = await MockToken.deploy("Aave DAI", "aDAI", 18);

        // Deploy mock Uniswap v4 pool manager
        const MockPoolManager = await ethers.getContractFactory("MockPoolManager");
        const poolManager = await MockPoolManager.deploy();

        // Deploy mock Aave pool
        const MockAavePool = await ethers.getContractFactory("MockAavePool");
        const aavePool = await MockAavePool.deploy();

        // Deploy mock rewards controller
        const MockRewardsController = await ethers.getContractFactory("MockRewardsController");
        const rewardsController = await MockRewardsController.deploy();

        // Deploy LiquidHook
        const LiquidHook = await ethers.getContractFactory("LiquidHook");
        const liquidHook = await LiquidHook.deploy(
            poolManager.address,
            aavePool.address,
            rewardsController.address
        );

        // Setup tokens for testing
        await usdc.mint(owner.address, ethers.parseUnits("10000", 6));
        await dai.mint(owner.address, ethers.parseUnits("10000", 18));

        // Transfer tokens to LiquidHook for testing
        await usdc.transfer(liquidHook.address, ethers.parseUnits("1000", 6));
        await dai.transfer(liquidHook.address, ethers.parseUnits("1000", 18));

        // Setup mock aTokens
        await aavePool.setAToken(usdc.address, aUsdc.address);
        await aavePool.setAToken(dai.address, aDai.address);

        // Setup mock rewards
        await rewardsController.setRewards(aUsdc.address, ethers.parseUnits("100", 6));
        await rewardsController.setRewards(aDai.address, ethers.parseUnits("100", 18));

        return {
            liquidHook, poolManager, aavePool, rewardsController,
            usdc, dai, aUsdc, aDai, owner, user1, user2
        };
    }

    // Pool key structure for Uniswap v4
    const createPoolKey = (token0, token1, fee) => {
        return {
            currency0: token0.address,
            currency1: token1.address,
            fee: fee,
            tickSpacing: 60,
            hooks: ethers.ZeroAddress // Modern Hardhat kullanımı
        };
    };

    // Mock balance delta
    const createBalanceDelta = (delta0, delta1) => {
        return {
            amount0: delta0,
            amount1: delta1
        };
    };

    describe("Initialization", function () {
        it("Should initialize with correct addresses", async function () {
            const { liquidHook, aavePool, rewardsController } = await loadFixture(deployFixture);

            expect(await liquidHook.aavePool()).to.equal(aavePool.address);
            expect(await liquidHook.rewardsController()).to.equal(rewardsController.address);
            expect(await liquidHook.reservePercentage()).to.equal(2000); // 20% default
        });
    });

    describe("Token Management", function () {
        it("Should add supported tokens", async function () {
            const { liquidHook, usdc, aUsdc } = await loadFixture(deployFixture);

            await liquidHook.addSupportedToken(usdc.address, aUsdc.address);

            expect(await liquidHook.supportedTokens(usdc.address)).to.be.true;
            expect(await liquidHook.aTokens(usdc.address)).to.equal(aUsdc.address);
        });

        // Diğer testler de benzer şekilde güncellenecek...
    });

    // Diğer test blokları da benzer şekilde güncellenecek...
});