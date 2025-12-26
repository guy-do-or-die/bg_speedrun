import { ethers } from "hardhat";

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Deployer:", deployer.address);

    // Using getContractAt with addresses from deployments if getContract fails, 
    // but try getContract first as it's standard in SE-2
    let balloons;
    let dex;
    try {
        balloons = await ethers.getContract("Balloons", deployer);
        dex = await ethers.getContract("DEX", deployer);
    } catch (e) {
        console.log("getContract failed, trying manual addresses from deployments...");
        // Fallback or just fail - usually we can rely on standard hardhat-deploy behavior if network is correct
        throw e;
    }

    const dexAddress = await dex.getAddress();
    console.log("DEX Address:", dexAddress);

    const totalLiquidity = await dex.totalLiquidity();
    console.log("Current Total Liquidity:", totalLiquidity.toString());

    if (totalLiquidity > 0n) {
        console.log("DEX already initialized.");
        return;
    }

    console.log("Approving DEX...");
    const approveTx = await balloons.approve(dexAddress, ethers.parseEther("100"));
    console.log("Approve Tx sent:", approveTx.hash);
    await approveTx.wait();
    console.log("Approved.");

    console.log("Initializing DEX...");
    const initTx = await dex.init(ethers.parseEther("0.002"), {
        value: ethers.parseEther("0.002"),
        gasLimit: 200000,
    });
    console.log("Init Tx sent:", initTx.hash);
    await initTx.wait();

    console.log("DEX Initialized Successfully!");
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
