"use client";

import { useState } from "react";

export default function UnWrapTab() {
  const [unwrapAmount, setUnwrapAmount] = useState("");

  const [txStep, setTxStep] = useState<
    "idle" | "approving" | "wrapping" | "unwrapping"
  >("idle");

  const [isLoading, setIsLoading] = useState(false);

  const handleUnwrap = async () => {
    setIsLoading(true);
    setTxStep("unwrapping");
    try {
      // Simulate unwrap transaction
      await new Promise((resolve) => setTimeout(resolve, 2000));
      // Reset form after success
      setUnwrapAmount("");
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
          value={unwrapAmount}
          onChange={(e) => setUnwrapAmount(e.target.value)}
          placeholder="cUSDC amount to unwrap"
          className="w-full p-3 rounded-lg bg-gray-700 border border-gray-600 focus:outline-none focus:border-blue-500"
          disabled={isLoading}
        />

        <button
          onClick={handleUnwrap}
          disabled={!unwrapAmount || isLoading}
          className={`w-full py-3 rounded-lg font-medium transition-all ${
            unwrapAmount && !isLoading
              ? "bg-blue-600 hover:bg-blue-700"
              : "bg-gray-700 cursor-not-allowed"
          }`}
        >
          {txStep === "unwrapping" ? (
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
