// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IUniswapV3FactoryVariant {
    function getPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external view returns (address pool);
}
