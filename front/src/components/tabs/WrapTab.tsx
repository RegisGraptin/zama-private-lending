"use client";

import { useAllowance } from "@/utils/hook/token";
import { useState } from "react";
import { Address, erc20Abi, getAddress, parseUnits } from "viem";
import {
  useAccount,
  useBalance,
  useWaitForTransactionReceipt,
  useWriteContract,
} from "wagmi";

export default function WrapTab() {
  const [wrapAmount, setWrapAmount] = useState("");
  const [isApproved, setIsApproved] = useState(false);

  const [txStep, setTxStep] = useState<
    "idle" | "approving" | "wrapping" | "unwrapping"
  >("idle");

  const [isLoading, setIsLoading] = useState(false);

  const { address: userAddress } = useAccount();

  const { data: userBalance } = useBalance({
    address: userAddress,
    token: getAddress(process.env.NEXT_PUBLIC_ASSET_ADDRESS!),
  });

  const {
    data: allowance,
    isLoading: isLoadingAllowance,
    refetch: refetchAllowance,
  } = useAllowance(getAddress(process.env.NEXT_PUBLIC_ASSET_ADDRESS!), [
    userAddress!,
    getAddress(process.env.NEXT_PUBLIC_CONFIDENTIAL_LAYER_ADDRESS!),
  ]);

  const {
    writeContract: writeApproveToken,
    data: txHashApprove,
    isPending: isApproving,
  } = useWriteContract();

  const { isSuccess: isTxApproveConfirmed, isLoading: isTxApproveLoading } =
    useWaitForTransactionReceipt({
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
    if (!isApproved) return;

    setIsLoading(true);
    setTxStep("wrapping");
    try {
      // Simulate wrap transaction
      await new Promise((resolve) => setTimeout(resolve, 2000));
      // Reset form after success
      setWrapAmount("");
      setIsApproved(false);
    } finally {
      setIsLoading(false);
      setTxStep("idle");
    }
  };

  return (
    <>
      <div className="space-y-4">
        <input
          type="number"
          value={wrapAmount}
          onChange={(e) => setWrapAmount(e.target.value)}
          placeholder="USDC amount to wrap"
          className="w-full p-3 rounded-lg bg-gray-700 border border-gray-600 focus:outline-none focus:border-blue-500"
          disabled={isLoading}
        />

        <div className="flex gap-4">
          {!isApproved ? (
            <button
              onClick={handleApprove}
              disabled={!wrapAmount || isLoading}
              className={`flex-1 py-3 rounded-lg font-medium transition-all ${
                wrapAmount && !isLoading
                  ? "bg-blue-600 hover:bg-blue-700"
                  : "bg-gray-700 cursor-not-allowed"
              }`}
            >
              {txStep === "approving" ? (
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
