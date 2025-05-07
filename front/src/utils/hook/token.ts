import { Address, erc20Abi, getAddress } from "viem";
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
