import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

// AAVE Doc deployment addresses
// https://github.com/bgd-labs/aave-address-book/blob/main/src/AaveV3Sepolia.sol

// Sepolia address
export const AAVE_POOL_ADDRESS = "0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951";
export const USDC = "0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8";
export const aUSDC = "0x16dA4541aD1807f4443d92D26044C1147406EB80";

export const maxDecryptionDelay = 1800; // 30 minutes

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;

  const deployed = await deploy("ConfidentialLendingLayer", {
    from: deployer,
    args: [AAVE_POOL_ADDRESS, USDC, aUSDC, maxDecryptionDelay],
    log: true,
  });

  console.log(`ConfidentialLendingLayer contract: `, deployed.address);
};
export default func;
func.id = "deploy_confidentialLendingLayer"; // id required to prevent reexecution
func.tags = ["ConfidentialLendingLayer"];
