// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IArrakisMetaLP {
    function deposit(uint64 proportion) external;
    function withdraw(uint24 proportion, address receiver) external returns (uint256 amount0, uint256 amount1);
    function rebalance(address[] calldata targets, bytes[] calldata payloads) external;
    function setManager(address newManager) external;
    function addModule(address newModule) external;
    function removeModule(address oldModule) external;
    function addSwapRouter(address newSwapRouter) external;
    function removeSwapRouter(address oldSwapRouter) external;

    function totalUnderlying() external view returns (uint256 amount0, uint256 amount1);
    function totalUnderlyingAtPrice(uint256 priceX96) external view returns (uint256 amount0, uint256 amount1);
    function getInits() external view returns (uint256 init0, uint256 init1);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function manager() external view returns (address);
    function modules() external view returns (address[] memory);
    function swapRouters() external view returns (address[] memory);
}