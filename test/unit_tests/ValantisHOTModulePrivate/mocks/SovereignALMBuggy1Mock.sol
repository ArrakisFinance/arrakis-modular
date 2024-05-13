// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeCast} from
    "@openzeppelin/contracts/utils/math/SafeCast.sol";

contract SovereignALMBuggy1Mock {
    address public token0;
    address public token1;

    function setToken0AndToken1(
        address token0_,
        address token1_
    ) external {
        token0 = token0_;
        token1 = token1_;
    }

    function getReservesAtPrice(uint160)
        external
        view
        returns (uint128 reserves0, uint128 reserves1)
    {
        reserves0 = SafeCast.toUint128(
            IERC20(token0).balanceOf(address(this))
        );
        reserves1 = SafeCast.toUint128(
            IERC20(token1).balanceOf(address(this))
        );
    }

    function depositLiquidity(
        uint256 amount0,
        uint256 amount1,
        uint160,
        uint160
    )
        external
        returns (uint256 amount0Deposited, uint256 amount1Deposited)
    {
        IERC20(token0).transferFrom(
            msg.sender, address(this), amount0 / 2
        );
        IERC20(token1).transferFrom(
            msg.sender, address(this), amount1
        );

        amount0Deposited = amount0;
        amount1Deposited = amount1;
    }

    function withdrawLiquidity(
        uint256 amount0,
        uint256 amount1,
        address receiver,
        uint160,
        uint160
    ) external {
        IERC20(token0).transfer(receiver, amount0);
        IERC20(token1).transfer(receiver, amount1);
    }
}
