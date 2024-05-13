// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {SwapAndAddData} from "../structs/SRouter.sol";

interface IRouterSwapExecutor {
    // #region errors.

    error OnlyRouter(address caller, address router);
    error AddressZero();
    error SwapCallFailed();
    error ReceivedBelowMinimum();

    // #endregion errors.

    /// @notice function used to swap tokens.
    /// @param _swapData struct containing all the informations for swapping.
    /// @return amount0Diff the difference in token0 amount before and after the swap.
    /// @return amount1Diff the difference in token1 amount before and after the swap.
    function swap(SwapAndAddData memory _swapData)
        external
        payable
        returns (uint256 amount0Diff, uint256 amount1Diff);
}
