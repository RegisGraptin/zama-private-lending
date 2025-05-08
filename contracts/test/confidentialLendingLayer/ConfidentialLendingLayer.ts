import { time } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";

import { awaitAllDecryptionResults } from "../asyncDecrypt";
import { createInstance } from "../instance";
import { getSigners, initSigners } from "../signers";
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

  it("should allocate the rewards", async function () {
    // Bob - 600_000
    // Carol - 400_000

    // Bob
    const bobAddress = await this.signers.bob.getAddress();
    const bobAmount = 600_000;

    await this.usdc.connect(this.signers.bob).mint(bobAddress, bobAmount);
    await this.usdc.connect(this.signers.bob).approve(this.contractAddress, bobAmount);
    await this.contract.connect(this.signers.bob).wrap(bobAmount);

    const bobInput = this.fhevm.createEncryptedInput(this.contractAddress, bobAddress);
    const bobInputs = await bobInput.add64(bobAmount).encrypt();
    await this.contract.connect(this.signers.bob).lendToAave(bobInputs.handles[0], bobInputs.inputProof);

    // Carol
    const carolAddress = await this.signers.carol.getAddress();
    const carolAmount = 400_000;

    await this.usdc.connect(this.signers.carol).mint(carolAddress, carolAmount);
    await this.usdc.connect(this.signers.carol).approve(this.contractAddress, carolAmount);
    await this.contract.connect(this.signers.carol).wrap(carolAmount);

    const carolInput = this.fhevm.createEncryptedInput(this.contractAddress, carolAddress);
    const carolInputs = await carolInput.add64(carolAmount).encrypt();
    await this.contract.connect(this.signers.carol).lendToAave(carolInputs.handles[0], carolInputs.inputProof);

    // Execute the round
    await this.contract.callNextRound();
    await awaitAllDecryptionResults();

    // Verify allocation
    expect(await this.usdc.balanceOf(await this.aave.getAddress())).to.be.eq(1_000_000);
    expect(await this.aave.balanceOf(this.contractAddress)).to.be.eq(1_000_000);

    // Simulate rewards - 10% reward
    await this.aave.rewards(this.contractAddress, 100_000);
    await time.increase(3600);
    await this.contract.callNextRound();
    await awaitAllDecryptionResults();

    // Bob withdraw the totality
    const bobTotalAmount = 660_000; // + 60_000;
    const bobInputWithdraw = this.fhevm.createEncryptedInput(this.contractAddress, bobAddress);
    const bobInputsWithdraw = await bobInputWithdraw.add64(bobTotalAmount).encrypt();
    await this.contract
      .connect(this.signers.bob)
      .withdrawFromAave(bobInputsWithdraw.handles[0], bobInputsWithdraw.inputProof);

    await time.increase(3600);
    await this.contract.callNextRound();
    await awaitAllDecryptionResults();

    expect(await this.aave.balanceOf(this.contractAddress)).to.be.eq(1_100_000 - bobTotalAmount);
    expect(await this.usdc.balanceOf(this.contractAddress)).to.be.eq(bobTotalAmount);

    // Unwrap bob token
    await this.contract.connect(this.signers.bob).unwrap(600_000);
    await awaitAllDecryptionResults();

    expect(await this.usdc.balanceOf(bobAddress)).to.be.eq(600_000);
  });
});
