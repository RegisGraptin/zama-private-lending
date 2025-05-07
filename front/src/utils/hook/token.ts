import { Address, erc20Abi, formatUnits, getAddress } from "viem";
import { useReadContract } from "wagmi";

export function useAllowance(
  tokenAddress: Address | string | undefined,
  args: [`0x${string}`, `0x${string}`]
) {
  return useReadContract({
    address: getAddress(tokenAddress!),
    abi: erc20Abi,
    functionName: "allowance",
    args,
    query: {
      enabled: !!tokenAddress, // Only enable when address exists
    },
  });
}

export function displayBalance({
  value,
  decimals,
}: {
  value: bigint;
  decimals: number;
}) {
  const formattedAmount = formatUnits(value, decimals);
  return new Intl.NumberFormat("en-US", {
    style: "decimal",
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
    useGrouping: true,
  }).format(BigInt(formattedAmount));
}
