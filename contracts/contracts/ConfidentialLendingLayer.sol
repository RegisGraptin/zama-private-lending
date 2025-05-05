// SPDX-License-Identifier: BSD-3-Clause-Clear

pragma solidity ^0.8.24;

import "fhevm/lib/TFHE.sol";
import "fhevm/config/ZamaFHEVMConfig.sol";
import "fhevm-contracts/contracts/token/ERC20/ConfidentialERC20Wrapped.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IPool } from "@aave-v3-core/contracts/protocol/pool/Pool.sol";
import { IPoolAddressesProvider } from "@aave-v3-core/contracts/protocol/configuration/PoolAddressesProvider.sol";

/// @notice This contract implements an encrypted ERC20-like token with confidential balances using Zama's FHE library.
/// @dev It supports typical ERC20 functionality such as transferring tokens, minting, and setting allowances,
/// @dev but uses encrypted data types.
contract ConfidentialLendingLayer is ConfidentialERC20Wrapped {
    using SafeERC20 for IERC20Metadata;

    address asset;
    euint256 nextRoundAction;

    // Track user balance

    //  balances --> available
    // mapping(address account => euint256 balance) internal _availableBalance; // Waiting balance
    mapping(address account => euint64 balance) internal _lendingBalances; // Balance in lending

    /// @notice Address of the AAVE Pool Address Provider allowing us to fetch the pool address
    address public immutable POOL_ADDRESSES_PROVIDER_ADDRESS;

    function _aavePoolAddress() internal view returns (address) {
        return IPoolAddressesProvider(POOL_ADDRESSES_PROVIDER_ADDRESS).getPool();
    }

    constructor(
        address _aaveProviderAddress,
        address erc20_,
        uint256 maxDecryptionDelay_
    ) ConfidentialERC20Wrapped(erc20_, maxDecryptionDelay_) {
        POOL_ADDRESSES_PROVIDER_ADDRESS = _aaveProviderAddress;
        asset = erc20_;

        // Negative number not managed
        nextRoundAction = TFHE.asEuint256(1e18);
        TFHE.allowThis(nextRoundAction);
    }

    // wrap / unwrap manage that

    function lendToAave(einput eRequestedAmount, bytes calldata inputProof) external {
        euint64 eAmount = TFHE.asEuint64(eRequestedAmount, inputProof);

        // Verify enough funds
        ebool isTransferable = TFHE.le(eAmount, _balances[msg.sender]);
        euint64 transferValue = TFHE.select(isTransferable, eAmount, TFHE.asEuint64(0));

        // Update the user balance
        euint64 newBalance = TFHE.sub(_balances[msg.sender], transferValue);
        _balances[msg.sender] = newBalance;
        TFHE.allowThis(newBalance);
        TFHE.allow(newBalance, msg.sender);

        // Update lending balance
        euint64 newLending = TFHE.add(_lendingBalances[msg.sender], transferValue);
        _lendingBalances[msg.sender] = newLending;
        TFHE.allowThis(newLending);
        TFHE.allow(newLending, msg.sender);

        // Update round state
        TFHE.add(nextRoundAction, transferValue);

        // TODO: Should I keep track user round for reward?
    }

    function withdrawFromAave(einput eRequestedAmount, bytes calldata inputProof) external {
        euint64 eAmount = TFHE.asEuint64(eRequestedAmount, inputProof);

        // Verify enough funds
        ebool isTransferable = TFHE.le(eAmount, _lendingBalances[msg.sender]);
        euint64 transferValue = TFHE.select(isTransferable, eAmount, TFHE.asEuint64(0));

        // Update lending balance
        euint64 newLending = TFHE.sub(_lendingBalances[msg.sender], transferValue);
        _lendingBalances[msg.sender] = newLending;
        TFHE.allowThis(newLending);
        TFHE.allow(newLending, msg.sender);

        // Update the user balance
        euint64 newBalance = TFHE.add(_balances[msg.sender], transferValue);
        _balances[msg.sender] = newBalance;
        TFHE.allowThis(newBalance);
        TFHE.allow(newBalance, msg.sender);

        // Update round state
        TFHE.sub(nextRoundAction, transferValue);

        // TODO: Need to keep track user round reward

        // Create function for user to see all reward
    }

    function executeRound(uint256 requestId, uint256 lendingAmout) external onlyGateway {
        if (lendingAmout > 1e18) {
            // Lending action
            _aaveSupply(lendingAmout - 1e18);
        } else {
            _aaveWithdraw(1e18 - lendingAmout);
        }
    }

    //// Gateway callback

    function _aaveSupply(uint256 amount) internal {
        IERC20(asset).approve(_aavePoolAddress(), amount);
        IPool(_aavePoolAddress()).supply(asset, amount, address(this), 0);

        // TODO: Add event
    }

    function _aaveWithdraw(uint256 amount) internal {
        IPool(_aavePoolAddress()).withdraw(asset, amount, msg.sender);

        // TODO: Add event
    }
}
