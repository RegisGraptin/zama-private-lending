import { ethers } from "hardhat";

import type { AAVEPoolMock, ConfidentialLendingLayer, ERC20Mock } from "../../types";
import { getSigners } from "../signers";

// AAVE Doc deployment addresses
// https://github.com/bgd-labs/aave-address-book/blob/main/src/AaveV3Sepolia.sol

// Sepolia address
export const POOL_ADDRESSES_PROVIDER_ADDRESS = "0x012bAC54348C0E635dCAc9D5FB99f06F24136C9A";
export const USDC = "0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8";
export const aUSDC = "0x16dA4541aD1807f4443d92D26044C1147406EB80";

export const maxDecryptionDelay = 1800; // 30 minutes

export async function deployConfidentialLendingLayer(): Promise<[ConfidentialLendingLayer, AAVEPoolMock, ERC20Mock]> {
  const signers = await getSigners();

  // Mock USDC
  const usdcContractFactory = await ethers.getContractFactory("ERC20Mock");
  const usdcContract = await usdcContractFactory.connect(signers.alice).deploy();
  await usdcContract.waitForDeployment();
  const usdcAddress = await usdcContract.getAddress();

  // Mock AAVE contract
  const aaveContractFactory = await ethers.getContractFactory("AAVEPoolMock");
  const aaveContract = await aaveContractFactory.connect(signers.alice).deploy(usdcContract);
  await aaveContract.waitForDeployment();
  const aaveAddress = await aaveContract.getAddress();

  // Confidential Lending Layer
  const contractFactory = await ethers.getContractFactory("ConfidentialLendingLayer");
  const contract = await contractFactory.connect(signers.alice).deploy(aaveAddress, usdcAddress, aaveAddress, 1800);
  await contract.waitForDeployment();

  return [contract, aaveContract, usdcContract];
}
