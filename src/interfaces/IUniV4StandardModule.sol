// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";

interface IUniV4StandardModule {
    // #region errors.

    error Currency0DtToken0(address currency0, address token0);
    error Currency1DtToken1(address currency1, address token1);
    error Currency1DtToken0(address currency1, address token0);
    error Currency0DtToken1(address currency0, address token1);
    error SqrtPriceZero();
    error OnlyPoolManager();
    error OnlyModuleCaller();
    error InvalidCurrencyDelta();
    error RangeShouldBeActive(int24 tickLower, int24 tickUpper);
    error OverBurning();
    error TicksMisordered(int24 tickLower, int24 tickUpper);
    error TickLowerOutOfBounds(int24 tickLower);
    error TickUpperOutOfBounds(int24 tickUpper);
    error OnlyMetaVaultOrManager();
    error SamePool();
    error NoModifyLiquidityHooks();
    error OverMaxDeviation();
    error CallBackNotSupported();
    error NativeCoinCannotBeToken1();

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

    // #region only meta vault owner functions.

    function initialize(
        uint256 init0_,
        uint256 init1_,
        bool isInversed_,
        PoolKey calldata poolKey_,
        address metaVault_
    ) external;

    // #endregion only meta vault owner functions.

    // #region only manager functions.

    function setPool(
        PoolKey calldata poolKey_,
        LiquidityRange[] calldata liquidityRanges_
    ) external;

    function rebalance(
        LiquidityRange[] calldata liquidityRanges_
    )
        external
        returns (
            uint256 amount0Minted,
            uint256 amount1Minted,
            uint256 amount0Burned,
            uint256 amount1Burned
        );

    // #endregion only manager functions.

    // #region view functions.

    /// @notice function used to get the list of active ranges.
    /// @return ranges active ranges
    function getRanges() external view returns (Range[] memory ranges);

    function poolKey()
        external
        view
        returns (
            Currency currency0,
            Currency currency1,
            uint24 fee,
            int24 tickSpacing,
            IHooks hooks
        );

    // #endregion view functions.
}
