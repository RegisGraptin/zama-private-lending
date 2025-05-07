"use client";

import { useState } from "react";
import WrapLayer from "./layer/WrapLayer";
import LendLayer from "./layer/LendLayer";

export default function ActionLayer() {
  const [activeTab, setActiveTab] = useState<"wrap" | "lend">("wrap");

  return (
    <>
      <div className="p-8">
        <div className="max-w-2xl mx-auto">
          <h1 className="text-3xl font-bold mb-8 text-center">
            Private DeFi Vault
          </h1>

          {/* Navigation Tabs */}
          <div className="flex gap-4 mb-8 justify-center">
            <button
              onClick={() => setActiveTab("wrap")}
              className={`px-6 py-2 rounded-lg ${
                activeTab === "wrap"
                  ? "bg-blue-600"
                  : "bg-gray-700 hover:bg-gray-600"
              }`}
            >
              Confidential Tokens
            </button>
            <button
              onClick={() => setActiveTab("lend")}
              className={`px-6 py-2 rounded-lg ${
                activeTab === "lend"
                  ? "bg-blue-600"
                  : "bg-gray-700 hover:bg-gray-600"
              }`}
            >
              Private Lending
            </button>
          </div>

          {/* Wrap/Unwrap Section */}
          {activeTab === "wrap" && <WrapLayer />}

          {/* Lend/Withdraw Section */}
          {activeTab === "lend" && <LendLayer />}
        </div>
      </div>
    </>
  );
}
