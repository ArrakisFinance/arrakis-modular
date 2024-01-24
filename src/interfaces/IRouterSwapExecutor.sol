// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {SwapAndAddData} from "../structs/SRouter.sol";

interface IRouterSwapExecutor {
    function swap(SwapAndAddData memory _swapData)
        external
        returns (uint256 amount0Diff, uint256 amount1Diff);
}