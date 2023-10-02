// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IArrakisLPModuleVault {
    function deposit(uint256 proportion_) external returns(uint256 amount0, uint256 amount1);
    function withdraw(uint256 proportion_) external returns (uint256 amount0, uint256 amount1);

    function token0() external view returns (address);
    function token1() external view returns (address);
    function getInits() external view returns (uint256 init0, uint256 init1);
    function totalUnderlying() external view returns (uint256 amount0, uint256 amount1);
    function totalUnderlyingAtPrice(uint256 priceX96_) external view returns (uint256 amount0, uint256 amount1);
}