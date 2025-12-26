import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat/";
import { DiceGame, RiggedRoll } from "../typechain-types";

const deployRiggedRoll: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;

  const diceGame: DiceGame = await ethers.getContract("DiceGame");
  const diceGameAddress = await diceGame.getAddress();

  // Uncomment to deploy RiggedRoll contract
  // Uncomment to deploy RiggedRoll contract
  await deploy("RiggedRoll", {
    from: deployer,
    log: true,
    args: [diceGameAddress],
    autoMine: true,
  });

  const riggedRoll: RiggedRoll = await ethers.getContract("RiggedRoll", deployer);

  console.log("Funding RiggedRoll with 0.002 ETH...");
  const wallet = (await hre.ethers.getSigners())[0];
  await wallet.sendTransaction({
    to: await riggedRoll.getAddress(),
    value: hre.ethers.parseEther("0.002"),
  });

  // Please replace the text "Your Address" with your own address.
  // try {
  //   await riggedRoll.transferOwnership("Your Address");
  // } catch (err) {
  //   console.log(err);
  // }
};

export default deployRiggedRoll;

deployRiggedRoll.tags = ["RiggedRoll"];
