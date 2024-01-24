// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {AddLiquidityData, AddLiquidityPermit2Data, RemoveLiquidityData, RemoveLiquidityPermit2Data, SwapAndAddData, SwapAndAddPermit2Data} from "../structs/SRouter.sol";

interface IArrakisPublicVaultRouter {
    // #region errors.

    error AddressZero();
    error NotEnoughNativeTokenSent();
    error OnlyERC20TypeVault(bytes32 vaultType);
    error EmptyMaxAmounts();
    error NothingToMint();
    error NothingToBurn();
    error BelowMinAmounts();
    error SwapCallFailed();
    error ReceivedBelowMinimum();
    error LengthMismatch();
    error NoNativeToken();
    error Deposit0();
    error Deposit1();

    // #endregion errors.

    // #region events.

    event Swapped(
        bool zeroForOne,
        uint256 amount0Diff,
        uint256 amount1Diff,
        uint256 amountOutSwap
    );

    // #endregion events.

    // #region functions.

    function addLiquidity(
        AddLiquidityData memory params_
    )
        external
        payable
        returns (uint256 amount0, uint256 amount1, uint256 sharesReceived);

    function swapAndAddLiquidity(
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

    function removeLiquidity(
        RemoveLiquidityData memory params_
    ) external returns (uint256 amount0, uint256 amount1);

    function addLiquidityPermit2(
        AddLiquidityPermit2Data memory params_
    )
        external
        payable
        returns (uint256 amount0, uint256 amount1, uint256 sharesReceived);

    function swapAndAddLiquidityPermit2(
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

    function removeLiquidityPermit2(
        RemoveLiquidityPermit2Data memory params_
    ) external returns (uint256 amount0, uint256 amount1);

    // #endregion functions.
}
