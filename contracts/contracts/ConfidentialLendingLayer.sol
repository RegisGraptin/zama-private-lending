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
/// @dev FIXME:
/// @dev FIXME:
contract ConfidentialLendingLayer is ConfidentialERC20Wrapped {
    using SafeERC20 for IERC20Metadata;

    /// @notice Precision factor for reward computation
    uint64 constant PRECISION_FACTOR = 1e8;

    /// @notice Offset used to simulate signed integers with uint64 (euint64)
    /// to handle lending update position.
    // value > INT64_OFFSET represent a supply action
    uint64 constant INT64_OFFSET = 2 ** 63;

    /// @notice ERC20 assets used in lending
    address asset;
    address aAsset;

    euint256 nextRoundAction;

    uint256 lastActionTime;

    // Variable used to compute rewards
    uint256 public globalRewardIndex;
    uint256 public lastUpdateTime;

    /// @notice Defined the total amount currently lended in the protocol
    uint256 totalLendedAmount;

    // Track user balance
    struct UserInfo {
        uint256 principal;
        uint256 rewardIndex;
        uint256 accruedRewards;
    }
    mapping(address => UserInfo) public users;

    //  balances --> available
    // mapping(address account => euint256 balance) internal _availableBalance; // Waiting balance
    mapping(address account => euint64 balance) internal _lendingBalances; // Balance in lending

    mapping(address account => uint256 index) internal _userIndex;

    mapping(address account => bool locked) internal lockedLiquidity;

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
        nextRoundAction = TFHE.asEuint256(INT64_OFFSET);
        TFHE.allowThis(nextRoundAction);
    }

    function updateUser(address user) internal {
        // uint256 deltaIndex = (newReward * 1e18) / totalSupply;

        UserInfo storage u = users[user];

        // euint64 deltaIndex = TFHE.sub(globalRewardIndex, _userIndex[msg.sender]);

        uint256 deltaIndex = globalRewardIndex - _userIndex[msg.sender];
        if (deltaIndex > 0) {
            euint64 userPrincipal = _lendingBalances[user];

            euint64 reward = TFHE.div(TFHE.mul(userPrincipal, TFHE.asEuint64(deltaIndex)), PRECISION_FACTOR);

            euint64 newBalance = TFHE.add(_lendingBalances[user], reward);
            _lendingBalances[user] = newBalance;
            TFHE.allowThis(newBalance);
            TFHE.allow(newBalance, msg.sender);

            _userIndex[msg.sender] = globalRewardIndex;

            // FIXME: Is needed ??
            // Update global totalDeposits too
            // totalDeposits += reward;
        }
    }

    // FIXME:
    // updateUser(msg.sender);

    // wrap / unwrap manage that

    // lend - block timestamps

    function lendToAave(einput eRequestedAmount, bytes calldata inputProof) external {
        require(!lockedLiquidity[msg.sender], "LOCKED_LIQUIDITY");

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
        TFHE.add(nextRoundAction, transferValue);

        // TODO: Should I keep track user round for reward?
    }

    function withdrawFromAave(einput eRequestedAmount, bytes calldata inputProof) external {
        require(!lockedLiquidity[msg.sender], "LOCKED_LIQUIDITY");

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
        TFHE.sub(nextRoundAction, transferValue);

        // TODO: Need to keep track user round reward

        // Create function for user to see all reward
    }

    function callNextRound() external {
        require(block.timestamp > lastActionTime + 30 minutes, "NOT_ENOUGH_TIME");

        // Compute and assigned all the rewards
        // FIXME: _asset need to update
        uint256 newReward = IERC20(aAsset).balanceOf(address(this)) - totalLendedAmount;

        uint256 deltaIndex = (newReward * PRECISION_FACTOR) / totalLendedAmount;
        globalRewardIndex += deltaIndex;
        lastUpdateTime = block.timestamp;

        // Rewards are compound so we need to update the balance
        totalLendedAmount = IERC20(aAsset).balanceOf(address(this));

        // Update the lending position of the protocol
        uint256[] memory cts = new uint256[](1);
        cts[0] = Gateway.toUint256(nextRoundAction);
        uint256 requestId = Gateway.requestDecryption(cts, this.executeRound.selector, 0, block.timestamp + 100, false);
    }

    function executeRound(uint256 requestId, uint256 lendingAmout) external onlyGateway {
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
