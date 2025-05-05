// SPDX-License-Identifier: BSD-3-Clause-Clear

pragma solidity ^0.8.24;

import "fhevm/lib/TFHE.sol";
import "fhevm/config/ZamaFHEVMConfig.sol";
import "fhevm-contracts/contracts/token/ERC20/ConfidentialERC20Wrapped.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IPool } from "@aave-v3-core/contracts/protocol/pool/Pool.sol";
import { IPoolAddressesProvider } from "@aave-v3-core/contracts/protocol/configuration/PoolAddressesProvider.sol";

/// @notice This contract implements an encrypted ERC20-like token with confidential balances using Zama's FHE library.
/// @dev It supports typical ERC20 functionality such as transferring tokens, minting, and setting allowances,
/// @dev but uses encrypted data types.
contract ConfidentialLendingLayer is ConfidentialERC20Wrapped {
    /// @notice Address of the AAVE Pool Address Provider allowing us to fetch the pool address
    address public immutable POOL_ADDRESSES_PROVIDER_ADDRESS;

    constructor(
        address _aaveProviderAddress,
        address erc20_,
        uint256 maxDecryptionDelay_
    ) ConfidentialERC20Wrapped(erc20_, maxDecryptionDelay_) {
        POOL_ADDRESSES_PROVIDER_ADDRESS = _aaveProviderAddress;
    }

    function _aavePoolAddress() internal view returns (address) {
        return IPoolAddressesProvider(POOL_ADDRESSES_PROVIDER_ADDRESS).getPool();
    }

    function supply(address asset, uint256 amount) external {
        IERC20(asset).transferFrom(msg.sender, address(this), amount);
        IERC20(asset).approve(_aavePoolAddress(), amount);
        IPool(_aavePoolAddress()).supply(asset, amount, address(this), 0);

        // TODO: Add event
    }

    function withdraw(address asset, uint256 amount) external {
        uint256 amountWitdraw = IPool(_aavePoolAddress()).withdraw(asset, amount, msg.sender);

        // TODO: Add event
    }
}
