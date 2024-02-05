// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {AddLiquidityData, AddLiquidityPermit2Data, RemoveLiquidityData, RemoveLiquidityPermit2Data, SwapAndAddData, SwapAndAddPermit2Data} from "../structs/SRouter.sol";

interface IArrakisPublicVaultRouter {
    // #region errors.

    error AddressZero();
    error NotEnoughNativeTokenSent();
    error NoNativeTokenAndValueNotZero();
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

    /// @notice addLiquidity adds liquidity to meta vault of iPnterest (mints L tokens)
    /// @param params_ AddLiquidityData struct containing data for adding liquidity
    /// @return amount0 amount of token0 transferred from msg.sender to mint `mintAmount`
    /// @return amount1 amount of token1 transferred from msg.sender to mint `mintAmount`
    /// @return sharesReceived amount of public vault tokens transferred to `receiver`
    function addLiquidity(
        AddLiquidityData memory params_
    )
        external
        payable
        returns (uint256 amount0, uint256 amount1, uint256 sharesReceived);

    /// @notice swapAndAddLiquidity transfer tokens to and calls RouterSwapExecutor
    /// @param params_ SwapAndAddData struct containing data for swap
    /// @return amount0 amount of token0 transferred from msg.sender to mint `mintAmount`
    /// @return amount1 amount of token1 transferred from msg.sender to mint `mintAmount`
    /// @return sharesReceived amount of public vault tokens transferred to `receiver`
    /// @return amount0Diff token0 balance difference post swap
    /// @return amount1Diff token1 balance difference post swap
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

    /// @notice removeLiquidity removes liquidity from vault and burns LP tokens
    /// @param params_ RemoveLiquidityData struct containing data for withdrawals
    /// @return amount0 actual amount of token0 transferred to receiver for burning `burnAmount`
    /// @return amount1 actual amount of token1 transferred to receiver for burning `burnAmount`
    function removeLiquidity(
        RemoveLiquidityData memory params_
    ) external returns (uint256 amount0, uint256 amount1);

    /// @notice addLiquidityPermit2 adds liquidity to public vault of interest (mints LP tokens)
    /// @param params_ AddLiquidityPermit2Data struct containing data for adding liquidity
    /// @return amount0 amount of token0 transferred from msg.sender to mint `mintAmount`
    /// @return amount1 amount of token1 transferred from msg.sender to mint `mintAmount`
    /// @return sharesReceived amount of public vault tokens transferred to `receiver`
    function addLiquidityPermit2(
        AddLiquidityPermit2Data memory params_
    )
        external
        payable
        returns (uint256 amount0, uint256 amount1, uint256 sharesReceived);

    /// @notice swapAndAddLiquidityPermit2 transfer tokens to and calls RouterSwapExecutor
    /// @param params_ SwapAndAddPermit2Data struct containing data for swap
    /// @return amount0 amount of token0 transferred from msg.sender to mint `mintAmount`
    /// @return amount1 amount of token1 transferred from msg.sender to mint `mintAmount`
    /// @return sharesReceived amount of public vault tokens transferred to `receiver`
    /// @return amount0Diff token0 balance difference post swap
    /// @return amount1Diff token1 balance difference post swap
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

    /// @notice removeLiquidityPermit2 removes liquidity from vault and burns LP tokens
    /// @param params_ RemoveLiquidityPermit2Data struct containing data for withdrawals
    /// @return amount0 actual amount of token0 transferred to receiver for burning `burnAmount`
    /// @return amount1 actual amount of token1 transferred to receiver for burning `burnAmount`
    function removeLiquidityPermit2(
        RemoveLiquidityPermit2Data memory params_
    ) external returns (uint256 amount0, uint256 amount1);

    // #endregion functions.
}
