"use client";

import { useState } from "react";
import { getAddress, parseUnits } from "viem";
import { useWaitForTransactionReceipt, useWriteContract } from "wagmi";
import ConfidentialLendingLayer from "@/abi/ConfidentialLendingLayer.json";

export default function UnWrapTab() {
  const [unwrapAmount, setUnwrapAmount] = useState("");

  // TODO: Read encrypted balance

  const { writeContract, data: txHashApprove, isPending } = useWriteContract();

  const { isLoading: isTxLoading } = useWaitForTransactionReceipt({
    hash: txHashApprove,
  });

  const handleUnwrap = async () => {
    writeContract({
      address: getAddress(process.env.NEXT_PUBLIC_ASSET_ADDRESS!),
      abi: ConfidentialLendingLayer.abi,
      functionName: "unwrap",
      args: [
        parseUnits(unwrapAmount, 6), // USDC has 6 decimals
      ],
    });
  };

  return (
    <>
      <div className="space-y-4">
        <input
          type="number"
          value={unwrapAmount}
          onChange={(e) => setUnwrapAmount(e.target.value)}
          placeholder="cUSDC amount to unwrap"
          className="w-full p-3 rounded-lg bg-gray-700 border border-gray-600 focus:outline-none focus:border-blue-500"
          disabled={isPending}
        />

        <button
          onClick={handleUnwrap}
          disabled={!unwrapAmount || isPending || isTxLoading}
          className={`w-full py-3 rounded-lg font-medium transition-all ${
            unwrapAmount && !isPending && !isTxLoading
              ? "bg-blue-600 hover:bg-blue-700"
              : "bg-gray-700 cursor-not-allowed"
          }`}
        >
          {isPending || isTxLoading ? (
            <span className="flex items-center justify-center gap-2">
              <span className="animate-spin">🌀</span>
              Unwrapping...
            </span>
          ) : (
            "Unwrap to USDC"
          )}
        </button>
      </div>
    </>
  );
}
