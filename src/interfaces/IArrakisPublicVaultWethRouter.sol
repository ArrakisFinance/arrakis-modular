// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {
    AddLiquidityData,
    SwapAndAddData,
    AddLiquidityPermit2Data,
    SwapAndAddPermit2Data
} from "../structs/SRouter.sol";

interface IArrakisPublicVaultWethRouter {

    // #region errors.
    error MsgValueZero();
    error NativeTokenNotSupported();
    error MsgValueDTMaxAmount();
    error NoWethToken();
    error Permit2WethNotAuthorized();
    // #endregion errors.

    function wrapAndAddLiquidity(
        AddLiquidityData memory params_
    ) external payable returns (uint256 amount0, uint256 amount1, uint256 sharesReceived);

    function wrapAndSwapAndAddLiquidity(
        SwapAndAddData memory params_
    )
        external
        payable
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 sharesReceived,
            uint256 amount0Diff,
            uint256 amount1Diff
        );

    function wrapAndAddLiquidityPermit2(
        AddLiquidityPermit2Data memory params_
    )
        external
        payable
        returns (uint256 amount0, uint256 amount1, uint256 sharesReceived);

    function wrapAndSwapAndAddLiquidityPermit2(
        SwapAndAddPermit2Data memory params_
    )
        external
        payable
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 sharesReceived,
            uint256 amount0Diff,
            uint256 amount1Diff
        );
}