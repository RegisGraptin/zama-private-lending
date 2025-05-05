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
    // lending
    mapping(address account => euint256 balance) internal _availableBalance; // Waiting balance
    mapping(address account => euint256 balance) internal _lendingBalance; // Balance in lending

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

    function deposit(uint256 amount) external {
        ERC20_TOKEN.safeTransferFrom(msg.sender, address(this), amount);

        // Increase user available balance
        euint256 newAvailableBalance = _availableBalance[msg.sender] + TFHE.asEuint256(amount);
        _availableBalance[msg.sender] = newAvailableBalance;

        // Authorize access
        TFHE.allowThis(newAvailableBalance);
        TFHE.allow(newAvailableBalance, msg.sender);
    }

    function withdraw(uint256 amount) external {
        // Verify the user has enough funds
        euint256 eAmount = TFHE.asEuint256(amount);
        ebool canWithdraw = TFHE.le(eAmount, _availableBalance[msg.sender]);
        euint256 transferValue = TFHE.select(canWithdraw, eAmount, TFHE.asEuint256(0));

        // Call the gateway to decrypt and transfer the value

        uint256[] memory cts = new uint256[](1);
        cts[0] = Gateway.toUint256(eAmount);
        uint256 requestId = Gateway.requestDecryption(
            cts,
            this.gatewayCallbackDecryptBid.selector,
            0,
            block.timestamp + 100,
            false
        );
    }

    function lendToAave(einput eRequestedAmount, bytes calldata inputProof) external {
        euint256 eAmount = TFHE.asEuint256(eRequestedAmount, inputProof);

        // Verify enough funds
        ebool canTransfer = TFHE.le(amount, _balances[msg.sender]);

        euint256 newBalanceAccount = TFHE.add(_lending[msg.sender], eAmount);
        _lending[msg.sender] = newBalanceAccount;

        TFHE.allowThis(newBalanceAccount);
        TFHE.allow(newBalanceAccount, msg.sender);
    }

    function withdrawFromAave(einput eRequestedAmount, bytes calldata inputProof) external {
        euint256 eAmount = TFHE.asEuint256(eRequestedAmount, inputProof);

        euint256 newBalanceAccount = TFHE.sub(_lending[msg.sender], eAmount);
        _lending[msg.sender] = newBalanceAccount;

        TFHE.allowThis(newBalanceAccount);
        TFHE.allow(newBalanceAccount, msg.sender);
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
