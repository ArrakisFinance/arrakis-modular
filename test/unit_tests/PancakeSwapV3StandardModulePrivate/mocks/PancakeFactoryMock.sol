// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IUniswapV3FactoryVariant} from
    "../../../../src/interfaces/IUniswapV3FactoryVariant.sol";

contract PancakeFactoryMock is IUniswapV3FactoryVariant {
    mapping(address => mapping(address => mapping(uint24 => address))) private _pools;
    address public owner;
    uint8 public feeProtocol;

    function setPool(address token0, address token1, uint24 fee, address pool) external {
        _pools[token0][token1][fee] = pool;
        _pools[token1][token0][fee] = pool; // Symmetric mapping
    }

    function getPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external view returns (address pool) {
        return _pools[tokenA][tokenB][fee];
    }

    function createPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external returns (address pool) {
        // Mock implementation - return a deterministic address
        pool = address(uint160(uint256(keccak256(abi.encode(tokenA, tokenB, fee)))));
        _pools[tokenA][tokenB][fee] = pool;
        _pools[tokenB][tokenA][fee] = pool;
    }
}