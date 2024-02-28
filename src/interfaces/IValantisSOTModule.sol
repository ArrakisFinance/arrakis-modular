// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ISovereignPool} from "./ISovereignPool.sol";
import {ISOT} from "./ISOT.sol";
import {IOracleWrapper} from "./IOracleWrapper.sol";

interface IValantisSOTModule {
    // #region errors.

    /// @notice
    error NoNativeToken();
    error OnlyPool(address caller, address pool);
    error AmountsZeros();
    error Actual0DifferentExpected(uint256 actual0, uint256 expected0);
    error Actual1DifferentExpected(uint256 actual1, uint256 expected1);
    error NotImplemented();
    error ExpectedMinReturnTooLow();
    error MaxSlippageGtTenPercent();
    error NotEnoughToken0();
    error NotEnoughToken1();
    error SwapCallFailed();
    error SlippageTooHigh();
    error NotDepositedAllToken0();
    error NotDepositedAllToken1();
    error OverMaxDeviation();
    error Deposit0();
    error Deposit1();

    // #endregion errors.

    // #region events.

    event LogSwap(
        uint256 oldBalance0,
        uint256 oldBalance1,
        uint256 newBalance0,
        uint256 newBalance1
    );

    // #endregion events.

    // #region state modifying functions.

    /// @notice initialize function to delegate call onced the beacon proxy is deployed,
    /// for initializing the valantis module.
    /// who can call deposit and withdraw functions.
    /// @param pool_ address of the valantis sovereign pool.
    /// @param alm_ address of the valantis SOT ALM.
    /// @param init0_ initial amount of token0 to provide to valantis module.
    /// @param init1_ initial amount of token1 to provide to valantis module.
    /// @param maxSlippage_ allowed to manager for rebalancing the inventory using
    /// swap.
    /// @param oracle_ address of the oracle used by the valantis SOT module.
    /// @param metaVault_ address of the meta vault
    function initialize(
        address pool_,
        address alm_,
        uint256 init0_,
        uint256 init1_,
        uint24 maxSlippage_,
        address oracle_,
        address metaVault_
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

    /// @notice fucntion used to set range on valantis AMM
    /// @param _sqrtPriceLowX96 lower bound of the range in sqrt price.
    /// @param _sqrtPriceHighX96 upper bound of the range in sqrt price.
    /// @param _expectedSqrtSpotPriceUpperX96 expected lower limit of current spot
    /// price (to prevent sandwich attack and manipulation).
    /// @param _expectedSqrtSpotPriceLowerX96 expected upper limit of current spot
    /// price (to prevent sandwich attack and manipulation).
    function setPriceBounds(
        uint128 _sqrtPriceLowX96,
        uint128 _sqrtPriceHighX96,
        uint160 _expectedSqrtSpotPriceUpperX96,
        uint160 _expectedSqrtSpotPriceLowerX96
    ) external;

    // #endregion state modifiying functions.

    // #region view functions.

    /// @notice function used to get the valantis sot pool.
    function pool() external view returns (ISovereignPool);

    /// @notice function used to get the valantis sot alm/ liquidity module.
    function alm() external view returns (ISOT);

    /// @notice function used to get the oracle that
    /// will be used to proctect rebalances.
    function oracle() external view returns (IOracleWrapper);

    /// @notice function used to get the max slippage that
    /// can occur during swap rebalance.
    function maxSlippage() external view returns (uint24);

    // #endregion view functions.
}
