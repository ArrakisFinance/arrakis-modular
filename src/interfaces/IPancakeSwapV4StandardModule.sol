// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PoolKey} from "@pancakeswap/v4-core/src/types/PoolKey.sol";

interface IPancakeSwapV4StandardModule {
    // #region errors.

    error Currency0DtToken0(address currency0, address token0);
    error Currency1DtToken1(address currency1, address token1);
    error Currency1DtToken0(address currency1, address token0);
    error Currency0DtToken1(address currency0, address token1);
    error SqrtPriceZero();
    error MaxSlippageGtTenPercent();
    error NativeCoinCannotBeToken1();
    error NoRemoveOrAddLiquidityHooks();
    error OnlyMetaVaultOwner();
    error InsufficientFunds();
    error AmountZero();
    error BurnToken0();
    error BurnToken1();
    error MintToken0();
    error MintToken1();
    error SamePool();

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
    event LogApproval(
        address indexed spender, uint256 amount0, uint256 amount1
    );
    event LogRebalance(
        LiquidityRange[] liquidityRanges,
        uint256 amount0Minted,
        uint256 amount1Minted,
        uint256 amount0Burned,
        uint256 amount1Burned
    );
    event LogSetPool(PoolKey oldPoolKey, PoolKey poolKey);
    // #endregion events.
}
