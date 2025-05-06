import { ethers } from "hardhat";

import type { ConfidentialLendingLayer } from "../../types";
import { getSigners } from "../signers";

// AAVE Doc deployment addresses
// https://github.com/bgd-labs/aave-address-book/blob/main/src/AaveV3Sepolia.sol

// Sepolia address
export const POOL_ADDRESSES_PROVIDER_ADDRESS = "0x012bAC54348C0E635dCAc9D5FB99f06F24136C9A";
export const USDC = "0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8";
export const aUSDC = "0x16dA4541aD1807f4443d92D26044C1147406EB80";

export async function deployConfidentialLendingLayer(): Promise<ConfidentialLendingLayer> {
  const signers = await getSigners();

  const contractFactory = await ethers.getContractFactory("ConfidentialLendingLayer");
  const contract = await contractFactory.connect(signers.alice).deploy(POOL_ADDRESSES_PROVIDER_ADDRESS, USDC, aUSDC);
  await contract.waitForDeployment();

  return contract;
}
