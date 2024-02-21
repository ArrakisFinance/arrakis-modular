// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {
    AddLiquidityData,
    SwapAndAddData,
    RemoveLiquidityData,
    AddLiquidityPermit2Data,
    SwapAndAddPermit2Data,
    RemoveLiquidityPermit2Data
} from "../structs/SRouter.sol";

interface IArrakisPublicVaultWethRouter {

    // #region errors.
    error MsgValueZero();
    error NativeTokenNotSupported();
    error MsgValueDTMaxAmount();
    error NoWethToken();
    error Permit2WethNotAuthorized();
    // #endregion errors.

    function wethAndAddLiquidity(
        AddLiquidityData memory params_
    ) external payable returns (uint256 amount0, uint256 amount1, uint256 sharesReceived);

    function wethAndSwapAndAddLiquidity(
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
    
    function removeLiquidityAndUnwrap(
        RemoveLiquidityData memory params_
    ) 
        external
        returns (uint256 amount0, uint256 amount1);

    function wethAddLiquidityPermit2(
        AddLiquidityPermit2Data memory params_
    )
        external
        payable
        returns (uint256 amount0, uint256 amount1, uint256 sharesReceived);

    function wethSwapAndAddLiquidityPermit2(
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

    function removeLiquidityPermit2AndUnwrap(
         RemoveLiquidityPermit2Data memory params_
    )
        external
        returns (uint256 amount0, uint256 amount1);
}