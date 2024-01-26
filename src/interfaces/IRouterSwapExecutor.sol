// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {SwapAndAddData} from "../structs/SRouter.sol";

interface IRouterSwapExecutor {

    // #region errors.

    error OnlyRouter(address caller, address router);
    error AddressZero();
    error SwapCallFailed();
    error ReceivedBelowMinimum();

    // #endregion errors.


    function swap(SwapAndAddData memory _swapData)
        external
        payable
        returns (uint256 amount0Diff, uint256 amount1Diff);
}