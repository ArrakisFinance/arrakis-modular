// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IUniswapV3Factory {
    function getPool(
        address tokenA,
        address tokenB,
        int24 tickSpacing
    ) external view returns (address pool);
}
