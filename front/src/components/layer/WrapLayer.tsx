"use client";

import { useState } from "react";
import WrapTab from "../tabs/WrapTab";
import UnWrapTab from "../tabs/UnWrapTab";

export default function WrapLayer() {
  const [activeAction, setActiveAction] = useState<"wrap" | "unwrap">("wrap");

  return (
    <div className="bg-gray-800 p-6 rounded-xl shadow-lg">
      <div className="flex gap-4 mb-6">
        <button
          onClick={() => setActiveAction("wrap")}
          className={`px-4 py-2 rounded-lg ${
            activeAction === "wrap"
              ? "bg-blue-600"
              : "bg-gray-700 hover:bg-gray-600"
          }`}
        >
          Wrap
        </button>
        <button
          onClick={() => setActiveAction("unwrap")}
          className={`px-4 py-2 rounded-lg ${
            activeAction === "unwrap"
              ? "bg-blue-600"
              : "bg-gray-700 hover:bg-gray-600"
          }`}
        >
          Unwrap
        </button>
      </div>

      {activeAction === "wrap" ? <WrapTab /> : <UnWrapTab />}
    </div>
  );
}
