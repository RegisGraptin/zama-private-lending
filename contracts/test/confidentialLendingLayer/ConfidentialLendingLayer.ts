import { expect } from "chai";
import { network } from "hardhat";

import { createInstance } from "../instance";
import { reencryptEuint64 } from "../reencrypt";
import { getSigners, initSigners } from "../signers";
import { debug } from "../utils";
import { deployConfidentialLendingLayer } from "./ConfidentialLendingLayer.fixture";

describe("ConfidentialERC20", function () {
  before(async function () {
    await initSigners();
    this.signers = await getSigners();
  });

  beforeEach(async function () {
    const contract = await deployConfidentialLendingLayer();
    this.contractAddress = await contract.getAddress();
    this.erc20 = contract;
    this.fhevm = await createInstance();
  });

  it("should mint the contract", async function () {
    // TODO:
  });
});
