"use client";

import { useState } from "react";

export default function LendLayer() {

    const [lendAmount, setLendAmount] = useState('');
    const [roundTimestamp, setRoundTimestamp] = useState('');

    return (
        <>
        <div className="bg-gray-800 p-6 rounded-xl shadow-lg">
            <h2 className="text-xl font-semibold mb-4">Lend/Withdraw cUSDC</h2>
            <div className="space-y-4">
              <input
                type="number"
                value={lendAmount}
                onChange={(e) => setLendAmount(e.target.value)}
                placeholder="Amount"
                className="w-full p-3 rounded-lg bg-gray-700 border border-gray-600 focus:outline-none focus:border-blue-500"
              />
              <input
                type="number"
                value={roundTimestamp}
                onChange={(e) => setRoundTimestamp(e.target.value)}
                placeholder="Execution timestamp"
                className="w-full p-3 rounded-lg bg-gray-700 border border-gray-600 focus:outline-none focus:border-blue-500"
              />
              <div className="flex gap-4">
                <button
                  onClick={() => {/* Handle lend */}}
                  className="flex-1 py-3 bg-blue-600 hover:bg-blue-700 rounded-lg font-medium"
                >
                  Deposit to AAVE
                </button>
                <button
                  onClick={() => {/* Handle withdraw */}}
                  className="flex-1 py-3 bg-gray-700 hover:bg-gray-600 rounded-lg font-medium"
                >
                  Withdraw from AAVE
                </button>
              </div>
              <div className="text-sm text-gray-400 mt-4">
                <p>AAVE Deposits: {/* Add balance here */}</p>
                <p>Transactions execute after specified timestamp to protect privacy</p>
              </div>
            </div>
          </div></>
    )

}