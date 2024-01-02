// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";

interface IUniV4NativeModule {
    // #region errors.

    error Token0GteToken1();
    error Currency0DtToken0(address currency0, address token0);
    error Currency1DtToken1(address currency1, address token1);
    error SqrtPriceZero();
    error TickZero();
    error OnlyPoolManager();
    error OnlyModuleCaller();
    error InvalidCurrencyDelta();
    error RangeShouldBeActive(int24 tickLower, int24 tickUpper);
    error OverBurning();
    error RangeNotFound();
    error LiquidityToAddEqZero();
    error LiquidityToRemoveEqZero();
    error TicksMisordered(int24 tickLower, int24 tickUpper);
    error TickLowerOutOfBounds(int24 tickLower);
    error TickUpperOutOfBounds(int24 tickUpper);
    error OnlyMetaVaultOrManager();
    error NotImplemented();

    // #endregion errors.

    // #region events.

    event LogSetPool(PoolKey oldPoolKey, PoolKey poolKey);
    event LogAddLiquidity(
        uint128 liquidityAdded,
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0,
        uint256 amount1
    );

    event LogRemoveLiquidity(
        uint128 liquidityRemoved,
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0,
        uint256 amount1
    );

    // #endregion events.

    // #region only manager functions.

    function setPool(PoolKey calldata poolKey_) external;

    function addLiquidity(
        uint128 liquidityToAdd_,
        int24 tickLower_,
        int24 tickUpper_
    ) external returns (uint256 amount0, uint256 amount1);

    function removeLiquidity(
        uint128 liquidityToRemove_,
        int24 tickLower_,
        int24 tickUpper_
    ) external returns (uint256 amount0, uint256 amount1);

    // #endregion only manager functions.
}
