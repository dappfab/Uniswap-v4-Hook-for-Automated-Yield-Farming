const hre = require("hardhat");

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);

    // Aave adresleri
    const aavePoolAddress = "0x..."; // Hedef ağdaki Aave pool adresi
    const aaveRewardsControllerAddress = "0x..."; // Hedef ağdaki rewards controller adresi

    // Uniswap v4 pool manager adresi
    const poolManagerAddress = "0x..."; // Hedef ağdaki Uniswap v4 pool manager adresi

    const LiquidHook = await hre.ethers.getContractFactory("LiquidHook");
    const liquidHook = await LiquidHook.deploy(
        poolManagerAddress,
        aavePoolAddress,
        aaveRewardsControllerAddress
    );

    await liquidHook.deployed();

    console.log("LiquidHook deployed to:", liquidHook.address);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});