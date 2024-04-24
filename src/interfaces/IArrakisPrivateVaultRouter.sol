// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {
    AddLiquidityData,
    AddLiquidityPermit2Data,
    SwapAndAddData,
    SwapAndAddPermit2Data
} from "../structs/SPrivateRouter.sol";

interface IArrakisPrivateVaultRouter {
    // #region errors.

    error AddressZero();
    error NotEnoughNativeTokenSent();
    error OnlyPrivateVault();
    error OnlyDepositor();
    error RouterIsNotDepositor();
    error EmptyAmounts();
    error LengthMismatch();
    error Deposit0();
    error Deposit1();
    error MsgValueZero();
    error NativeTokenNotSupported();
    error MsgValueDTAmount();
    error NoWethToken();
    error Permit2WethNotAuthorized();
    // #endregion errors.

    // #region events.

    /// @notice event emitted when a swap happen before depositing.
    /// @param zeroForOne boolean indicating if we are swap token0 to token1 or the inverse.
    /// @param amount0Diff amount of token0 get or consumed by the swap.
    /// @param amount1Diff amount of token1 get or consumed by the swap.
    /// @param amountOutSwap minimum amount of tokens out wanted after swap.
    event Swapped(
        bool zeroForOne,
        uint256 amount0Diff,
        uint256 amount1Diff,
        uint256 amountOutSwap
    );

    // #endregion events.

    // #region functions.

    /// @notice function used to pause the router.
    /// @dev only callable by owner
    function pause() external;

    /// @notice function used to unpause the router.
    /// @dev only callable by owner
    function unpause() external;

    /// @notice addLiquidity adds liquidity to meta vault of interest (mints L tokens)
    /// @param params_ AddLiquidityData struct containing data for adding liquidity
    function addLiquidity(AddLiquidityData memory params_)
        external
        payable;

    /// @notice swapAndAddLiquidity transfer tokens to and calls RouterSwapExecutor
    /// @param params_ SwapAndAddData struct containing data for swap
    /// @return amount0Diff token0 balance difference post swap
    /// @return amount1Diff token1 balance difference post swap
    function swapAndAddLiquidity(SwapAndAddData memory params_)
        external
        payable
        returns (uint256 amount0Diff, uint256 amount1Diff);

    /// @notice addLiquidityPermit2 adds liquidity to public vault of interest (mints LP tokens)
    /// @param params_ AddLiquidityPermit2Data struct containing data for adding liquidity
    function addLiquidityPermit2(
        AddLiquidityPermit2Data memory params_
    ) external payable;

    /// @notice swapAndAddLiquidityPermit2 transfer tokens to and calls RouterSwapExecutor
    /// @param params_ SwapAndAddPermit2Data struct containing data for swap
    /// @return amount0Diff token0 balance difference post swap
    /// @return amount1Diff token1 balance difference post swap
    function swapAndAddLiquidityPermit2(
        SwapAndAddPermit2Data memory params_
    )
        external
        payable
        returns (uint256 amount0Diff, uint256 amount1Diff);

    /// @notice wrapAndAddLiquidity wrap eth and adds liquidity to meta vault of iPnterest (mints L tokens)
    /// @param params_ AddLiquidityData struct containing data for adding liquidity
    function wrapAndAddLiquidity(AddLiquidityData memory params_)
        external
        payable;

    /// @notice wrapAndSwapAndAddLiquidity wrap eth and transfer tokens to and calls RouterSwapExecutor
    /// @param params_ SwapAndAddData struct containing data for swap
    /// @return amount0Diff token0 balance difference post swap
    /// @return amount1Diff token1 balance difference post swap
    function wrapAndSwapAndAddLiquidity(SwapAndAddData memory params_)
        external
        payable
        returns (uint256 amount0Diff, uint256 amount1Diff);

    /// @notice wrapAndAddLiquidityPermit2 wrap eth and adds liquidity to public vault of interest (mints LP tokens)
    /// @param params_ AddLiquidityPermit2Data struct containing data for adding liquidity
    function wrapAndAddLiquidityPermit2(
        AddLiquidityPermit2Data memory params_
    ) external payable;

    /// @notice wrapAndSwapAndAddLiquidityPermit2 wrap eth and transfer tokens to and calls RouterSwapExecutor
    /// @param params_ SwapAndAddPermit2Data struct containing data for swap
    /// @return amount0Diff token0 balance difference post swap
    /// @return amount1Diff token1 balance difference post swap
    function wrapAndSwapAndAddLiquidityPermit2(
        SwapAndAddPermit2Data memory params_
    )
        external
        payable
        returns (uint256 amount0Diff, uint256 amount1Diff);

    // #endregion functions.
}
