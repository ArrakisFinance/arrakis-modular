// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";

interface IUniV4NativeModule {
    // #region errors.

    error Token0GteToken1();
    error Currency0DtToken0(address currency0, address token0);
    error Currency1DtToken1(address currency1, address token1);
    error SqrtPriceZero();
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
    error SamePool();
    error NoModifyLiquidityHooks();

    // #endregion errors.

    // #region structs.

    struct Range {
        int24 tickLower;
        int24 tickUpper;
    }

    struct LiquidityRange {
        Range range;
        int128 liquidity;
    }

    // #endregion structs.

    // #region events.

    event LogSetPool(PoolKey oldPoolKey, PoolKey poolKey);
    event LogRebalance(
        LiquidityRange[] liquidityRanges,
        uint256 amount0Minted,
        uint256 amount1Minted,
        uint256 amount0Burned,
        uint256 amount1Burned
    );

    // #endregion events.

    // #region only manager functions.

    function setPool(PoolKey calldata poolKey_) external;

    function rebalance(
        LiquidityRange[] calldata liquidityRanges_
    ) external returns (
            uint256 amount0Minted,
            uint256 amount1Minted,
            uint256 amount0Burned,
            uint256 amount1Burned);

    // #endregion only manager functions.
}
