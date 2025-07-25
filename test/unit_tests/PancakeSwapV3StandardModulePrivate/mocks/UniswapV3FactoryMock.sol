// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

contract UniswapV3FactoryMock {

    address public pool;

    function setPool(
        address pool_
    ) external {
        pool = pool_;
    }

    function getPool(
        address token0,
        address tokenB,
        uint24 fee
    ) external view returns (address) {
        return pool;
    }
}