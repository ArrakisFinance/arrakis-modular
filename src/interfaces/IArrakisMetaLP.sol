// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IArrakisLPModule} from "./IArrakisLPModule.sol";

interface IArrakisMetaLP is IArrakisLPModule {
    function rebalance(address[] calldata targets, bytes[] calldata payloads) external;
    function setManager(address newManager) external;
    function addModule(address newModule) external;
    function removeModule(address oldModule) external;
    function addSwapRouter(address newSwapRouter) external;
    function removeSwapRouter(address oldSwapRouter) external;

    function manager() external view returns (address);
    function modules() external view returns (address[] memory);
    function swapRouters() external view returns (address[] memory);
    function init0() external view returns (uint256);
    function init1() external view returns (uint256);
}