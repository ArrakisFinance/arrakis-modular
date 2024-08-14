// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IOracleWrapper} from "./IOracleWrapper.sol";

interface IValantisSOTModulePublic {
    // #region errors.

    error SlippageTooHigh();
    error NotEnoughToken0();
    error NotEnoughToken1();
    error SwapCallFailed();
    error OverMaxDeviation();

    // #endregion errors.

    // #region events.

    event LogSwap(
        uint256 oldBalance0,
        uint256 oldBalance1,
        uint256 newBalance0,
        uint256 newBalance1
    );

    // #endregion events.

    // #region functions.

    /// @notice set SOT and initialize manager fees function.
    /// @param alm_ address of the valantis SOT ALM.
    /// @param oracle_ address of the oracle used by the valantis SOT module.
    function setALMAndManagerFees(
        address alm_,
        address oracle_
    ) external;

    /// @notice function to swap token0->token1 or token1->token0 and then change
    /// inventory.
    /// @param zeroForOne_ boolean if true token0->token1, if false token1->token0.
    /// @param expectedMinReturn_ minimum amount of tokenOut expected.
    /// @param amountIn_ amount of tokenIn used during swap.
    /// @param router_ address of routerSwapExecutor.
    /// @param expectedSqrtSpotPriceUpperX96_ upper bound of current price.
    /// @param expectedSqrtSpotPriceLowerX96_ lower bound of current price.
    /// @param payload_ data payload used for swapping.
    function swap(
        bool zeroForOne_,
        uint256 expectedMinReturn_,
        uint256 amountIn_,
        address router_,
        uint160 expectedSqrtSpotPriceUpperX96_,
        uint160 expectedSqrtSpotPriceLowerX96_,
        bytes calldata payload_
    ) external;

    // #endregion functions.

    // #region view functions.

    /// @notice function used to get the oracle that
    /// will be used to proctect rebalances.
    function oracle() external view returns (IOracleWrapper);

    // #endregion view functions.
}
