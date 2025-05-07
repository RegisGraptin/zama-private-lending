import { expect } from "chai";
import { network } from "hardhat";

import { awaitAllDecryptionResults } from "../asyncDecrypt";
import { createInstance } from "../instance";
import { reencryptEuint64 } from "../reencrypt";
import { getSigners, initSigners } from "../signers";
import { debug } from "../utils";
import { deployConfidentialLendingLayer } from "./ConfidentialLendingLayer.fixture";

describe("ConfidentialLendingLayer", function () {
  before(async function () {
    await initSigners();
    this.signers = await getSigners();
  });

  beforeEach(async function () {
    const [contract, aaveContract, usdcContract] = await deployConfidentialLendingLayer();
    this.contractAddress = await contract.getAddress();
    this.contract = contract;
    this.usdc = usdcContract;
    this.aave = aaveContract;
    this.fhevm = await createInstance();
  });

  it("should wrap usdc token", async function () {
    const userAddress = await this.signers.alice.getAddress();

    // Funds some token to alice
    await this.usdc.mint(userAddress, 1_000_000);
    await this.usdc.approve(this.contractAddress, 1_000_000);
    await this.contract.wrap(1_000_000);

    // Contract balance should have increase
    expect(await this.usdc.balanceOf(this.contractAddress)).to.be.eq(1_000_000);
    expect(await this.usdc.balanceOf(userAddress)).to.be.eq(0);
  });

  it("should supply usdc token to AAVE", async function () {
    const userAddress = await this.signers.alice.getAddress();

    // Funds some token to alice
    await this.usdc.mint(userAddress, 1_000_000);
    await this.usdc.approve(this.contractAddress, 1_000_000);
    await this.contract.wrap(1_000_000);

    // Supply AAVE
    const supplyAmount = 500_000;
    const input = this.fhevm.createEncryptedInput(this.contractAddress, userAddress);
    const inputs = await input.add64(supplyAmount).encrypt();

    await this.contract.lendToAave(inputs.handles[0], inputs.inputProof);

    await this.contract.callNextRound();
    await awaitAllDecryptionResults();

    // Check AAVE Balance has the USDC
    expect(await this.usdc.balanceOf(await this.aave.getAddress())).to.be.eq(500_000);

    // Our contract should have the aUSDC
    expect(await this.aave.balanceOf(await this.contractAddress)).to.be.eq(500_000);
  });

  it("should supply aggregated usdc to AAVE", async function () {
    const users = [
      [this.signers.bob, 500_000],
      [this.signers.carol, 400_000],
      [this.signers.dave, 300_000],
    ];

    for (let index = 0; index < users.length; index++) {
      const [signer, amount] = users[index];

      const userAddress = await signer.getAddress();
      await this.usdc.connect(signer).mint(userAddress, amount);

      await this.usdc.connect(signer).approve(this.contractAddress, amount);
      await this.contract.connect(signer).wrap(amount);

      const input = this.fhevm.createEncryptedInput(this.contractAddress, userAddress);
      const inputs = await input.add64(amount).encrypt();

      await this.contract.connect(signer).lendToAave(inputs.handles[0], inputs.inputProof);
    }

    await this.contract.callNextRound();
    await awaitAllDecryptionResults();

    // Check balance
    const totalAmount = users.reduce((sum, [, amount]) => sum + amount, 0);
    expect(await this.usdc.balanceOf(await this.contractAddress)).to.be.eq(0);
    expect(await this.usdc.balanceOf(await this.aave.getAddress())).to.be.eq(totalAmount);
    expect(await this.aave.balanceOf(await this.contractAddress)).to.be.eq(totalAmount);
  });
});
