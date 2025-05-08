// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.24;

import { IPool } from "@aave-v3-core/contracts/protocol/pool/Pool.sol";

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "hardhat/console.sol";

contract AAVEPoolMock is ERC20 {
    using SafeERC20 for IERC20Metadata;

    constructor(
        IERC20Metadata asset
    ) ERC20(string(abi.encodePacked("a", asset.name())), string(abi.encodePacked("a", asset.symbol()))) {}

    function supply(address asset, uint256 amount, address onBehalfOf, uint16) external {
        _mint(onBehalfOf, amount);
        IERC20Metadata(asset).safeTransferFrom(onBehalfOf, address(this), amount);
    }

    function withdraw(address asset, uint256 amount, address to) external returns (uint256) {
        _burn(to, amount);
        IERC20Metadata(asset).safeTransfer(to, amount);
        return amount;
    }

    function rewards(address account, uint256 amount) public {
        _mint(account, amount);
    }
}
