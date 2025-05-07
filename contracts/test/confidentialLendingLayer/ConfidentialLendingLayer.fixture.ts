import { ethers } from "hardhat";

import type { AAVEPoolMock, ConfidentialLendingLayer, ERC20Mock } from "../../types";
import { getSigners } from "../signers";

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
