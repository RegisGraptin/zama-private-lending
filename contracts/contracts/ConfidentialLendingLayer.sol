// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.24;

import "fhevm/lib/TFHE.sol";
import "fhevm/config/ZamaFHEVMConfig.sol";
import "fhevm-contracts/contracts/token/ERC20/ConfidentialERC20Wrapped.sol";

import { SepoliaZamaFHEVMConfig } from "fhevm/config/ZamaFHEVMConfig.sol";
import { SepoliaZamaGatewayConfig } from "fhevm/config/ZamaGatewayConfig.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IPool } from "@aave-v3-core/contracts/protocol/pool/Pool.sol";

import "hardhat/console.sol";

/// @notice Confidential Lending Layer designed to obfuscate user lending amount.
/// @dev The system operates as a round system. At each iteration, it aggregates all user supply and withdrawal
/// requests, computes the net movement, and executes a single net operation on AAVE. This batching mechanism
/// preserves user privacy by preventing the exposure of individual transaction amounts.
contract ConfidentialLendingLayer is SepoliaZamaFHEVMConfig, SepoliaZamaGatewayConfig, ConfidentialERC20Wrapped {
    using SafeERC20 for IERC20Metadata;

    /// @notice Precision factor for reward computation
    uint64 constant PRECISION_FACTOR = 1e8;

    /// @notice Offset used to simulate signed integers with uint64 (euint64)
    /// to handle lending update position.
    // value > INT64_OFFSET represent a supply action
    uint64 constant INT64_OFFSET = 2 ** 63;

    /// @notice Address of the AAVE Pool Address
    address public immutable AAVE_POOL_ADDRESS;

    /// @notice ERC20 assets used in lending.
    address asset;
    address aAsset;

    /// @notice Index of the current round.
    uint256 currentRound;

    /// @notice Net liquidity change (supply/withdraw) scheduled for the next round.
    /// Scaled to INT64_OFFSET to handle supply or withdraw operation.
    euint256 nextRoundDelta;

    /// @notice Cumulative reward index to tracks global rewards per unit of principal over time.
    mapping(uint256 round => uint256 globalReward) internal _globalRewards;

    /// @notice Last round timestamps.
    uint256 public lastUpdateTime;

    /// @notice Defined the total amount currently lended in the protocol.
    uint256 totalLendedAmount;

    /// @notice User balance active in lending.
    mapping(address account => euint64 balance) internal _lendingBalances;

    /// @notice User reward index to compute lending reward.
    mapping(address account => uint256 index) internal _userIndex;

    /// @notice Track the user next round balance
    mapping(address account => uint256 lastRound) internal _userLastUpdatedRound;
    mapping(address account => euint64 balance) internal _userNextRoundDeposit;
    mapping(address account => euint64 balance) internal _userNextRoundWithdrawal;

    /// @notice Events to monitor liquidity movement to AAVE
    event LiquiditySupplied(uint256 amount);
    event LiquidityWithdrawn(uint256 amount);

    /// @notice Between each round, we need to wait allowing us to have time to aggregate multiple user transactions.
    error TooEarlyForNextRound();

    constructor(
        address _aavePoolAddress,
        address _erc20,
        address _aErc20,
        uint256 maxDecryptionDelay_
    ) ConfidentialERC20Wrapped(_erc20, maxDecryptionDelay_) {
        AAVE_POOL_ADDRESS = _aavePoolAddress;
        asset = _erc20;
        aAsset = _aErc20;

        // Scaled as negative number not managed
        nextRoundDelta = TFHE.asEuint256(INT64_OFFSET);
        TFHE.allowThis(nextRoundDelta);
    }

    function _updateUserRound(address user, uint256 roundId) internal {
        uint256 deltaIndex = _globalRewards[roundId] - _userIndex[user];
        if (deltaIndex > 0) {
            // Compute the reward using user contribution
            euint64 userPrincipal = _lendingBalances[user];
            euint64 reward = TFHE.div(TFHE.mul(userPrincipal, TFHE.asEuint64(deltaIndex)), PRECISION_FACTOR);

            // Update user balance
            euint64 newBalance = TFHE.add(_lendingBalances[user], reward);
            _lendingBalances[user] = newBalance;
            TFHE.allowThis(newBalance);
            TFHE.allow(newBalance, user);

            _userIndex[user] = _globalRewards[roundId];
        }
    }

    function _updateUser(address user) internal {
        // Lazy update on lending position
        if (_userLastUpdatedRound[user] < currentRound) {
            // Compute previous reward of the last user round
            // In case of previous withdraw, we want to make sure to have the last remanining reward
            _updateUserRound(user, _userLastUpdatedRound[user]);

            /// Update lending balance
            euint64 newLendingBalance = TFHE.add(_lendingBalances[user], _userNextRoundDeposit[user]);
            newLendingBalance = TFHE.sub(newLendingBalance, _userNextRoundWithdrawal[user]);
            _lendingBalances[user] = newLendingBalance;
            TFHE.allowThis(newLendingBalance);
            TFHE.allow(newLendingBalance, user);

            // Update user balance
            euint64 newBalance = TFHE.add(_balances[user], _userNextRoundWithdrawal[user]);
            _balances[user] = newBalance;
            TFHE.allowThis(newBalance);
            TFHE.allow(newBalance, user);

            // Update state
            euint64 _roundDeposit = TFHE.asEuint64(0);
            TFHE.allowThis(_roundDeposit);
            _userNextRoundDeposit[user] = _roundDeposit;

            euint64 _roundWithdrawal = TFHE.asEuint64(0);
            TFHE.allowThis(_roundWithdrawal);
            _userNextRoundWithdrawal[user] = _roundWithdrawal;

            _userLastUpdatedRound[user] = currentRound;
        }

        _updateUserRound(user, currentRound);
    }

    function lendToAave(einput eRequestedAmount, bytes calldata inputProof) external {
        _updateUser(msg.sender); // Update user reward

        euint64 eAmount = TFHE.asEuint64(eRequestedAmount, inputProof);

        // Verify enough funds
        ebool isTransferable = TFHE.le(eAmount, _balances[msg.sender]);
        euint64 transferValue = TFHE.select(isTransferable, eAmount, TFHE.asEuint64(0));

        // Update the user balance
        euint64 newBalance = TFHE.sub(_balances[msg.sender], transferValue);
        _balances[msg.sender] = newBalance;
        TFHE.allowThis(newBalance);
        TFHE.allow(newBalance, msg.sender);

        // Update user deposit
        euint64 newDeposit = TFHE.add(_userNextRoundDeposit[msg.sender], transferValue);
        _userNextRoundDeposit[msg.sender] = newDeposit;
        TFHE.allowThis(newDeposit);
        TFHE.allow(newDeposit, msg.sender);

        // Update round state
        nextRoundDelta = TFHE.add(nextRoundDelta, transferValue);
        TFHE.allowThis(nextRoundDelta);
    }

    function withdrawFromAave(einput eRequestedAmount, bytes calldata inputProof) external {
        _updateUser(msg.sender); // Update user reward

        euint64 eAmount = TFHE.asEuint64(eRequestedAmount, inputProof);

        // Verify enough funds
        ebool isTransferable = TFHE.le(eAmount, _lendingBalances[msg.sender]);
        euint64 transferValue = TFHE.select(isTransferable, eAmount, TFHE.asEuint64(0));

        // Update withdrawal
        euint64 newWithdrawal = TFHE.add(_userNextRoundWithdrawal[msg.sender], transferValue);
        _userNextRoundWithdrawal[msg.sender] = newWithdrawal;
        TFHE.allowThis(newWithdrawal);
        TFHE.allow(newWithdrawal, msg.sender);

        // Update round state
        nextRoundDelta = TFHE.sub(nextRoundDelta, transferValue);
        TFHE.allowThis(nextRoundDelta);
    }

    function unwrap(uint64 amount) public override {
        _updateUser(msg.sender);
        super.unwrap(amount);
    }

    function callNextRound() external {
        if (block.timestamp <= lastUpdateTime + 30 minutes) {
            revert TooEarlyForNextRound();
        }

        lastUpdateTime = block.timestamp;

        // Update the lending position of the protocol
        uint256[] memory cts = new uint256[](1);
        cts[0] = Gateway.toUint256(nextRoundDelta);
        Gateway.requestDecryption(cts, this.executeRound.selector, 0, block.timestamp + 100, false);
    }

    function executeRound(uint256 /* requestId */, uint256 roundAmount) external onlyGateway {
        // Compute and assigned all the rewards
        uint256 newReward = IERC20(aAsset).balanceOf(address(this)) - totalLendedAmount;
        uint256 deltaIndex = 0;
        if (totalLendedAmount > 0) {
            deltaIndex = (newReward * PRECISION_FACTOR) / totalLendedAmount;
        }

        // Update the round
        currentRound++;
        _globalRewards[currentRound] = _globalRewards[currentRound - 1] + deltaIndex;

        // Rewards are compound so we need to update the lended amount
        totalLendedAmount = IERC20(aAsset).balanceOf(address(this));

        // Apply the net round operation
        if (roundAmount > INT64_OFFSET) {
            _aaveSupply(roundAmount - INT64_OFFSET);
        } else {
            _aaveWithdraw(INT64_OFFSET - roundAmount);
        }

        // Reset value for next round
        nextRoundDelta = TFHE.asEuint256(INT64_OFFSET);
        TFHE.allowThis(nextRoundDelta);
    }

    //// Gateway callback

    function _aaveSupply(uint256 amount) internal {
        totalLendedAmount += amount;
        IERC20(asset).approve(AAVE_POOL_ADDRESS, amount);
        IPool(AAVE_POOL_ADDRESS).supply(asset, amount, address(this), 0);
        emit LiquiditySupplied(amount);
    }

    function _aaveWithdraw(uint256 amount) internal {
        totalLendedAmount -= amount;
        IPool(AAVE_POOL_ADDRESS).withdraw(asset, amount, address(this));
        emit LiquidityWithdrawn(amount);
    }
}
