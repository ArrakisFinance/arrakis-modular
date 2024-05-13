// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IERC20, LpModuleMock} from "./LpModuleMock.sol";

contract BuggyLpModuleMock is LpModuleMock {
    function withdraw(
        address receiver_,
        uint256
    ) external override returns (uint256 amount0, uint256 amount1) {
        uint256 balance0 = token0.balanceOf(address(this));
        uint256 balance1 = token1.balanceOf(address(this));

        amount0 = balance0 / 2;
        amount1 = balance1 / 2;

        if (amount0 > 0) token0.transfer(receiver_, amount0);
        if (amount1 > 0) token1.transfer(receiver_, amount1);
    }
}
