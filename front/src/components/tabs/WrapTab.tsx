"use client";

import ConfidentialLendingLayer from "@/abi/ConfidentialLendingLayer.json";
import { getFHEInstance } from "@/lib/fhe";

import { displayBalance, useAllowance } from "@/utils/hook/token";
import { useState } from "react";
import { erc20Abi, getAddress, parseUnits, toHex } from "viem";
import {
  useAccount,
  useBalance,
  useWaitForTransactionReceipt,
  useWriteContract,
} from "wagmi";

export default function WrapTab() {
  const [wrapAmount, setWrapAmount] = useState("");

  const [txStep, setTxStep] = useState<
    "idle" | "approving" | "wrapping" | "unwrapping"
  >("idle");

  const [isLoading, setIsLoading] = useState(false);

  const { address: userAddress } = useAccount();

  const { data: userBalance } = useBalance({
    address: userAddress,
    token: getAddress(process.env.NEXT_PUBLIC_ASSET_ADDRESS!),
  });

  const { data: allowance, refetch: refetchAllowance } = useAllowance(
    getAddress(process.env.NEXT_PUBLIC_ASSET_ADDRESS!),
    [
      userAddress!,
      getAddress(process.env.NEXT_PUBLIC_CONFIDENTIAL_LAYER_ADDRESS!),
    ]
  );

  const {
    writeContract: writeApproveToken,
    data: txHashApprove,
    isPending: isPendingAllowance,
  } = useWriteContract();

  const { isLoading: isTxApproveLoading } = useWaitForTransactionReceipt({
    hash: txHashApprove,
  });

  const handleApprove = async () => {
    writeApproveToken({
      address: getAddress(process.env.NEXT_PUBLIC_ASSET_ADDRESS!),
      abi: erc20Abi,
      functionName: "approve",
      args: [
        getAddress(process.env.NEXT_PUBLIC_CONFIDENTIAL_LAYER_ADDRESS!),
        parseUnits(wrapAmount, 6), // USDC has 6 decimals
      ],
    });
  };

  const handleWrap = async () => {
    // einput eRequestedAmount, bytes calldata inputProof

    // Get the FHE instance
    console.log("Retrieve FHE Instance");
    const instance = getFHEInstance();

    if (!instance) {
      console.log("Instance loading...");
      return;
    }

    const input = instance.createEncryptedInput(
      process.env.NEXT_PUBLIC_CONFIDENTIAL_LAYER_ADDRESS!,
      "" + userAddress
    );

    // Add the user entry depending of the selected value
    input.add64(parseUnits(wrapAmount, 6));
    const encryptedInputs = await input.encrypt();

    writeApproveToken({
      address: getAddress(process.env.NEXT_PUBLIC_ASSET_ADDRESS!),
      abi: ConfidentialLendingLayer.abi,
      functionName: "lendToAave",
      args: [
        toHex(encryptedInputs.handles[0]),
        toHex(encryptedInputs.inputProof),
      ],
    });
  };

  return (
    <>
      <div className="space-y-4">
        {userBalance && (
          <p className="text-sm text-gray-400 truncate">
            Available: {displayBalance(userBalance)} USDC
          </p>
        )}

        <input
          type="number"
          value={wrapAmount}
          onChange={(e) => setWrapAmount(e.target.value)}
          placeholder="USDC amount to wrap"
          className="w-full p-3 rounded-lg bg-gray-700 border border-gray-600 focus:outline-none focus:border-blue-500"
          disabled={isLoading}
        />

        <div className="flex gap-4">
          {!allowance || parseUnits(wrapAmount, 6) > allowance ? (
            <button
              onClick={handleApprove}
              disabled={!wrapAmount || isPendingAllowance || isTxApproveLoading}
              className={`flex-1 py-3 rounded-lg font-medium transition-all ${
                wrapAmount && !isPendingAllowance && !isTxApproveLoading
                  ? "bg-blue-600 hover:bg-blue-700"
                  : "bg-gray-700 cursor-not-allowed"
              }`}
            >
              {isTxApproveLoading || isPendingAllowance ? (
                <span className="flex items-center justify-center gap-2">
                  <span className="animate-spin">🌀</span>
                  Approving...
                </span>
              ) : (
                "Approve USDC"
              )}
            </button>
          ) : (
            <button
              onClick={handleWrap}
              disabled={!wrapAmount || isLoading}
              className={`flex-1 py-3 rounded-lg font-medium transition-all ${
                wrapAmount && !isLoading
                  ? "bg-green-600 hover:bg-green-700"
                  : "bg-gray-700 cursor-not-allowed"
              }`}
            >
              {txStep === "wrapping" ? (
                <span className="flex items-center justify-center gap-2">
                  <span className="animate-spin">🌀</span>
                  Wrapping...
                </span>
              ) : (
                "Wrap to cUSDC"
              )}
            </button>
          )}
        </div>
      </div>
    </>
  );
}
