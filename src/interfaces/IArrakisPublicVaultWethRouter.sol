// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {AddLiquidityData, SwapAndAddData} from "../structs/SRouter.sol";

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
}