import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

/**
 * Deploys a contract named "YourContract" using the deployer account and
 * constructor arguments set to the deployer address
 *
 * @param hre HardhatRuntimeEnvironment object.
 */
const deployYourVotingContract: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;

  // 1. Deploy PoseidonT3
  const poseidon3 = await deploy("PoseidonT3", {
    from: deployer,
    log: true,
    autoMine: true,
  });

  // 2. Deploy LeanIMT
  const leanIMT = await deploy("LeanIMT", {
    from: deployer,
    log: true,
    autoMine: true,
    libraries: {
      PoseidonT3: poseidon3.address,
    },
  });

  // 3. Deploy Verifier
  await deploy("Verifier", {
    from: deployer,
    args: [],
    log: true,
    autoMine: true,
  });
  const verifier = await hre.ethers.getContract("Verifier", deployer);

  // 4. Deploy Voting
  await deploy("Voting", {
    from: deployer,
    // Contract constructor arguments
    args: [deployer, await verifier.getAddress(), "Should we build zk apps?"],
    log: true,
    autoMine: true,
    libraries: {
      LeanIMT: leanIMT.address,
    },
  });

  // Get the deployed contract to interact with it after deploying.
  const voting = await hre.ethers.getContract("Voting", deployer);
  console.log("👋 Voting contract deployed at:", await voting.getAddress());
};

export default deployYourVotingContract;

// Tags are useful if you have multiple deploy files and only want to run one of them.
// e.g. yarn deploy --tags YourContract
deployYourVotingContract.tags = ["YourVotingContract"];
