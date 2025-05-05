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

/// @notice FIXME:
/// we want to obfuscate the amount, not the user behaviour
contract ConfidentialLendingLayer is ConfidentialERC20Wrapped {
    using SafeERC20 for IERC20Metadata;

    /// @notice Precision factor for reward computation
    uint64 constant PRECISION_FACTOR = 1e8;

    /// @notice Offset used to simulate signed integers with uint64 (euint64)
    /// to handle lending update position.
    // value > INT64_OFFSET represent a supply action
    uint64 constant INT64_OFFSET = 2 ** 63;

    /// @notice ERC20 assets used in lending.
    address asset;
    address aAsset;

    /// @notice Index of the current round.
    uint256 currentRound;

    /// @notice Net liquidity change (supply/withdraw) scheduled for the next round.
    euint256 nextRoundDelta;

    /// @notice Cumulative reward index to tracks global rewards per unit of principal over time.
    mapping(uint256 round => uint256 globalReward) internal _globalRewards;

    /// @notice Last round timestamps.
    uint256 public lastUpdateTime;

    /// @notice Defined the total amount currently lended in the protocol.
    uint256 totalLendedAmount;

    /// @notice User balance active in lending.
    mapping(address account => euint64 balance) internal _lendingBalances;

    mapping(address account => uint256 index) internal _userIndex;

    /// @notice Track the user next round balance
    mapping(address account => uint256 lastRound) internal _userLastUpdatedRound;
    mapping(address account => euint64 balance) internal _userNextRoundDeposit;
    mapping(address account => euint64 balance) internal _userNextRoundWithdrawal;

    // FIXME: is it needed ? On withdraw ?
    // mapping(address account => bool locked) internal lockedLiquidity;

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
        aAsset = IPool(_aavePoolAddress()).getReserveData(asset).aTokenAddress;

        // Negative number not managed
        nextRoundDelta = TFHE.asEuint256(INT64_OFFSET);
        TFHE.allowThis(nextRoundDelta);
    }

    function _updateUserRound(address user, uint256 roundId) internal {
        uint256 deltaIndex = _globalRewards[roundId] - _userIndex[user];
        if (deltaIndex > 0) {
            euint64 userPrincipal = _lendingBalances[user];

            euint64 reward = TFHE.div(TFHE.mul(userPrincipal, TFHE.asEuint64(deltaIndex)), PRECISION_FACTOR);

            euint64 newBalance = TFHE.add(_lendingBalances[user], reward);
            _lendingBalances[user] = newBalance;
            TFHE.allowThis(newBalance);
            TFHE.allow(newBalance, user);

            _userIndex[user] = _globalRewards[roundId];
        }
    }

    function updateUser(address user) internal {
        // uint256 deltaIndex = (newReward * 1e18) / totalSupply;

        // Lazy update on lending position
        if (_userLastUpdatedRound[user] < currentRound) {
            // Compute previous reward of the last user round
            _updateUserRound(user, _userLastUpdatedRound[user]);

            // Update lending state

            // Apply deposit
            _lendingBalances[user] = TFHE.add(_lendingBalances[user], _userNextRoundDeposit[user]);
            _userNextRoundDeposit[user] = TFHE.asEuint64(0);

            // Apply withdrawal
            _lendingBalances[user] = TFHE.sub(_lendingBalances[user], _userNextRoundWithdrawal[user]);
            _userNextRoundWithdrawal[user] = TFHE.asEuint64(0);

            _userLastUpdatedRound[user] = currentRound;
        }

        _updateUserRound(user, currentRound);
    }

    // FIXME: Is needed ??
    // Update global totalDeposits too
    // totalDeposits += reward;

    // FIXME:
    // updateUser(msg.sender);

    // wrap / unwrap manage that

    // lend - block timestamps

    function lendToAave(einput eRequestedAmount, bytes calldata inputProof) external {
        // FIXME: the lending is not effective now
        // It will be on the next round

        // Update user reward
        updateUser(msg.sender);

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
        nextRoundDelta = TFHE.add(nextRoundDelta, transferValue);
        TFHE.allowThis(nextRoundDelta);

        // TODO: Should I keep track user round for reward?
    }

    function withdrawFromAave(einput eRequestedAmount, bytes calldata inputProof) external {
        // Update user reward
        updateUser(msg.sender);

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
        nextRoundDelta = TFHE.sub(nextRoundDelta, transferValue);
        TFHE.allowThis(nextRoundDelta);

        // TODO: Need to keep track user round reward
    }

    function callNextRound() external {
        require(block.timestamp > lastUpdateTime + 30 minutes, "NOT_ENOUGH_TIME");

        // Update the lending position of the protocol
        uint256[] memory cts = new uint256[](1);
        cts[0] = Gateway.toUint256(nextRoundDelta);
        uint256 requestId = Gateway.requestDecryption(cts, this.executeRound.selector, 0, block.timestamp + 100, false);
    }

    function executeRound(uint256 requestId, uint256 lendingAmout) external onlyGateway {
        // Compute and assigned all the rewards

        uint256 newReward = IERC20(aAsset).balanceOf(address(this)) - totalLendedAmount;

        uint256 deltaIndex = (newReward * PRECISION_FACTOR) / totalLendedAmount;

        currentRound++;
        _globalRewards[currentRound] = _globalRewards[currentRound - 1] + deltaIndex;

        lastUpdateTime = block.timestamp;

        // Rewards are compound so we need to update the balance
        totalLendedAmount = IERC20(aAsset).balanceOf(address(this));

        if (lendingAmout > INT64_OFFSET) {
            // Lending action
            _aaveSupply(lendingAmout - INT64_OFFSET);
        } else {
            _aaveWithdraw(INT64_OFFSET - lendingAmout);
        }
    }

    //// Gateway callback

    function _aaveSupply(uint256 amount) internal {
        totalLendedAmount += amount;
        IERC20(asset).approve(_aavePoolAddress(), amount);
        IPool(_aavePoolAddress()).supply(asset, amount, address(this), 0);

        // TODO: Add event
    }

    function _aaveWithdraw(uint256 amount) internal {
        totalLendedAmount -= amount;
        IPool(_aavePoolAddress()).withdraw(asset, amount, msg.sender);

        // TODO: Add event
    }
}
