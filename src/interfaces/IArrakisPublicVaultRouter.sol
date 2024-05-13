// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {
    AddLiquidityData,
    AddLiquidityPermit2Data,
    RemoveLiquidityData,
    RemoveLiquidityPermit2Data,
    SwapAndAddData,
    SwapAndAddPermit2Data
} from "../structs/SRouter.sol";

interface IArrakisPublicVaultRouter {
    // #region errors.

    error AddressZero();
    error NotEnoughNativeTokenSent();
    error NoNativeTokenAndValueNotZero();
    error OnlyPublicVault();
    error EmptyMaxAmounts();
    error NothingToMint();
    error NothingToBurn();
    error BelowMinAmounts();
    error SwapCallFailed();
    error ReceivedBelowMinimum();
    error LengthMismatch();
    error NoNativeToken();
    error MsgValueZero();
    error NativeTokenNotSupported();
    error MsgValueDTMaxAmount();
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

    /// @notice addLiquidity adds liquidity to meta vault of iPnterest (mints L tokens)
    /// @param params_ AddLiquidityData struct containing data for adding liquidity
    /// @return amount0 amount of token0 transferred from msg.sender to mint `mintAmount`
    /// @return amount1 amount of token1 transferred from msg.sender to mint `mintAmount`
    /// @return sharesReceived amount of public vault tokens transferred to `receiver`
    function addLiquidity(AddLiquidityData memory params_)
        external
        payable
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 sharesReceived
        );

    /// @notice swapAndAddLiquidity transfer tokens to and calls RouterSwapExecutor
    /// @param params_ SwapAndAddData struct containing data for swap
    /// @return amount0 amount of token0 transferred from msg.sender to mint `mintAmount`
    /// @return amount1 amount of token1 transferred from msg.sender to mint `mintAmount`
    /// @return sharesReceived amount of public vault tokens transferred to `receiver`
    /// @return amount0Diff token0 balance difference post swap
    /// @return amount1Diff token1 balance difference post swap
    function swapAndAddLiquidity(SwapAndAddData memory params_)
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
    function removeLiquidity(RemoveLiquidityData memory params_)
        external
        returns (uint256 amount0, uint256 amount1);

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
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 sharesReceived
        );

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

    /// @notice wrapAndAddLiquidity wrap eth and adds liquidity to meta vault of iPnterest (mints L tokens)
    /// @param params_ AddLiquidityData struct containing data for adding liquidity
    /// @return amount0 amount of token0 transferred from msg.sender to mint `mintAmount`
    /// @return amount1 amount of token1 transferred from msg.sender to mint `mintAmount`
    /// @return sharesReceived amount of public vault tokens transferred to `receiver`
    function wrapAndAddLiquidity(AddLiquidityData memory params_)
        external
        payable
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 sharesReceived
        );

    /// @notice wrapAndSwapAndAddLiquidity wrap eth and transfer tokens to and calls RouterSwapExecutor
    /// @param params_ SwapAndAddData struct containing data for swap
    /// @return amount0 amount of token0 transferred from msg.sender to mint `mintAmount`
    /// @return amount1 amount of token1 transferred from msg.sender to mint `mintAmount`
    /// @return sharesReceived amount of public vault tokens transferred to `receiver`
    /// @return amount0Diff token0 balance difference post swap
    /// @return amount1Diff token1 balance difference post swap
    function wrapAndSwapAndAddLiquidity(SwapAndAddData memory params_)
        external
        payable
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 sharesReceived,
            uint256 amount0Diff,
            uint256 amount1Diff
        );

    /// @notice wrapAndAddLiquidityPermit2 wrap eth and adds liquidity to public vault of interest (mints LP tokens)
    /// @param params_ AddLiquidityPermit2Data struct containing data for adding liquidity
    /// @return amount0 amount of token0 transferred from msg.sender to mint `mintAmount`
    /// @return amount1 amount of token1 transferred from msg.sender to mint `mintAmount`
    /// @return sharesReceived amount of public vault tokens transferred to `receiver`
    function wrapAndAddLiquidityPermit2(
        AddLiquidityPermit2Data memory params_
    )
        external
        payable
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 sharesReceived
        );

    /// @notice wrapAndSwapAndAddLiquidityPermit2 wrap eth and transfer tokens to and calls RouterSwapExecutor
    /// @param params_ SwapAndAddPermit2Data struct containing data for swap
    /// @return amount0 amount of token0 transferred from msg.sender to mint `mintAmount`
    /// @return amount1 amount of token1 transferred from msg.sender to mint `mintAmount`
    /// @return sharesReceived amount of public vault tokens transferred to `receiver`
    /// @return amount0Diff token0 balance difference post swap
    /// @return amount1Diff token1 balance difference post swap
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

    // #endregion functions.

    // #region view functions.

    /// @notice getMintAmounts used to get the shares we can mint from some max amounts.
    /// @param vault_ meta vault address.
    /// @param maxAmount0_ maximum amount of token0 user want to contribute.
    /// @param maxAmount1_ maximum amount of token1 user want to contribute.
    /// @return shareToMint maximum amount of share user can get for 'maxAmount0_' and 'maxAmount1_'.
    /// @return amount0ToDeposit amount of token0 user should deposit into the vault for minting 'shareToMint'.
    /// @return amount1ToDeposit amount of token1 user should deposit into the vault for minting 'shareToMint'.
    function getMintAmounts(
        address vault_,
        uint256 maxAmount0_,
        uint256 maxAmount1_
    )
        external
        view
        returns (
            uint256 shareToMint,
            uint256 amount0ToDeposit,
            uint256 amount1ToDeposit
        );

    // #endregion view functions.
}
