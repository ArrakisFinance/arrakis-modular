// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {
    UnderlyingPayload,
    PositionUnderlying,
    RangeData
} from "../structs/SUniswapV4.sol";
import {BASE} from "../constants/CArrakis.sol";
import {IUniV4ModuleBase} from "../interfaces/IUniV4ModuleBase.sol";

import {IPoolManager} from
    "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {FullMath} from "@uniswap/v4-core/src/libraries/FullMath.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {Position} from "@uniswap/v4-core/src/libraries/Position.sol";
import {FixedPoint128} from
    "@uniswap/v4-core/src/libraries/FixedPoint128.sol";
import {
    PoolIdLibrary,
    PoolId
} from "@uniswap/v4-core/src/types/PoolId.sol";
import {
    Currency,
    CurrencyLibrary
} from "@uniswap/v4-core/src/types/Currency.sol";
import {StateLibrary} from
    "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {TransientStateLibrary} from
    "@uniswap/v4-core/src/libraries/TransientStateLibrary.sol";

import {LiquidityAmounts} from
    "@v3-lib-0.8/contracts/LiquidityAmounts.sol";
import {SqrtPriceMath} from
    "@v3-lib-0.8/contracts/SqrtPriceMath.sol";

import {SafeCast} from
    "@openzeppelin/contracts/utils/math/SafeCast.sol";

library UnderlyingV4 {
    using StateLibrary for IPoolManager;
    using TransientStateLibrary for IPoolManager;
    using CurrencyLibrary for Currency;

    // solhint-disable-next-line function-max-lines
    function totalUnderlyingForMint(
        UnderlyingPayload memory underlyingPayload_,
        uint256 proportion_
    ) public view returns (uint256 amount0, uint256 amount1) {
        uint256 fee0;
        uint256 fee1;
        for (uint256 i; i < underlyingPayload_.ranges.length; i++) {
            {
                (uint256 a0, uint256 a1, uint256 f0, uint256 f1) =
                underlyingMint(
                    RangeData({
                        self: underlyingPayload_.self,
                        range: underlyingPayload_.ranges[i],
                        poolManager: underlyingPayload_.poolManager
                    }),
                    proportion_
                );
                amount0 += a0;
                amount1 += a1;
                fee0 += f0;
                fee1 += f1;
            }
        }

        amount0 += FullMath.mulDivRoundingUp(
            proportion_, fee0 + underlyingPayload_.leftOver0, BASE
        );
        amount1 += FullMath.mulDivRoundingUp(
            proportion_, fee1 + underlyingPayload_.leftOver1, BASE
        );
    }

    // solhint-disable-next-line function-max-lines
    function totalUnderlyingWithFees(
        UnderlyingPayload memory underlyingPayload_
    )
        public
        view
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 fee0,
            uint256 fee1
        )
    {
        return _totalUnderlyingWithFees(underlyingPayload_, 0);
    }

    function totalUnderlyingAtPriceWithFees(
        UnderlyingPayload memory underlyingPayload_,
        uint160 sqrtPriceX96_
    )
        public
        view
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 fee0,
            uint256 fee1
        )
    {
        return _totalUnderlyingWithFees(
            underlyingPayload_, sqrtPriceX96_
        );
    }

    function underlying(
        RangeData memory underlying_,
        uint160 sqrtPriceX96_
    )
        public
        view
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 fee0,
            uint256 fee1
        )
    {
        if (sqrtPriceX96_ == 0) {
            (sqrtPriceX96_,,,) = underlying_.poolManager.getSlot0(
                PoolIdLibrary.toId(underlying_.range.poolKey)
            );
        }

        PositionUnderlying memory positionUnderlying =
        PositionUnderlying({
            sqrtPriceX96: sqrtPriceX96_,
            poolManager: underlying_.poolManager,
            poolKey: underlying_.range.poolKey,
            self: underlying_.self,
            lowerTick: underlying_.range.lowerTick,
            upperTick: underlying_.range.upperTick
        });
        (amount0, amount1, fee0, fee1) =
            getUnderlyingBalances(positionUnderlying);
    }

    function underlyingMint(
        RangeData memory underlying_,
        uint256 proportion_
    )
        public
        view
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 fee0,
            uint256 fee1
        )
    {
        (uint160 sqrtPriceX96,,,) = underlying_.poolManager.getSlot0(
            PoolIdLibrary.toId(underlying_.range.poolKey)
        );
        PositionUnderlying memory positionUnderlying =
        PositionUnderlying({
            sqrtPriceX96: sqrtPriceX96,
            poolManager: underlying_.poolManager,
            poolKey: underlying_.range.poolKey,
            self: underlying_.self,
            lowerTick: underlying_.range.lowerTick,
            upperTick: underlying_.range.upperTick
        });
        (amount0, amount1, fee0, fee1) =
            getUnderlyingBalancesMint(positionUnderlying, proportion_);
    }

    // solhint-disable-next-line function-max-lines
    function getUnderlyingBalancesMint(
        PositionUnderlying memory positionUnderlying_,
        uint256 proportion_
    )
        public
        view
        returns (
            uint256 amount0Current,
            uint256 amount1Current,
            uint256 fee0,
            uint256 fee1
        )
    {
        Position.State memory positionState;
        {
            PoolId poolId =
                PoolIdLibrary.toId(positionUnderlying_.poolKey);

            // compute current fees earned
            (
                uint256 feeGrowthInside0X128,
                uint256 feeGrowthInside1X128
            ) = positionUnderlying_.poolManager.getFeeGrowthInside(
                poolId,
                positionUnderlying_.lowerTick,
                positionUnderlying_.upperTick
            );
            (
                positionState.liquidity,
                positionState.feeGrowthInside0LastX128,
                positionState.feeGrowthInside1LastX128
            ) = positionUnderlying_.poolManager.getPositionInfo(
                poolId,
                positionUnderlying_.self,
                positionUnderlying_.lowerTick,
                positionUnderlying_.upperTick,
                ""
            );
            (fee0, fee1) = _getFeesOwned(
                positionState,
                feeGrowthInside0X128,
                feeGrowthInside1X128
            );
        }

        // compute current holdings from liquidity
        (amount0Current, amount1Current) = getAmountsForDelta(
            positionUnderlying_.sqrtPriceX96,
            TickMath.getSqrtPriceAtTick(positionUnderlying_.lowerTick),
            TickMath.getSqrtPriceAtTick(positionUnderlying_.upperTick),
            SafeCast.toInt128(
                SafeCast.toInt256(
                    FullMath.mulDiv(
                        uint256(positionState.liquidity),
                        proportion_,
                        BASE
                    )
                )
            )
        );
    }

    // solhint-disable-next-line function-max-lines
    function getUnderlyingBalances(
        PositionUnderlying memory positionUnderlying_
    )
        public
        view
        returns (
            uint256 amount0Current,
            uint256 amount1Current,
            uint256 fee0,
            uint256 fee1
        )
    {
        PoolId poolId =
            PoolIdLibrary.toId(positionUnderlying_.poolKey);

        // compute current fees earned
        (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) =
        positionUnderlying_.poolManager.getFeeGrowthInside(
            poolId,
            positionUnderlying_.lowerTick,
            positionUnderlying_.upperTick
        );
        Position.State memory positionState;
        (
            positionState.liquidity,
            positionState.feeGrowthInside0LastX128,
            positionState.feeGrowthInside1LastX128
        ) = positionUnderlying_.poolManager.getPositionInfo(
            poolId,
            positionUnderlying_.self,
            positionUnderlying_.lowerTick,
            positionUnderlying_.upperTick,
            ""
        );
        (fee0, fee1) = _getFeesOwned(
            positionState, feeGrowthInside0X128, feeGrowthInside1X128
        );

        // compute current holdings from liquidity
        (amount0Current, amount1Current) = LiquidityAmounts
            .getAmountsForLiquidity(
            positionUnderlying_.sqrtPriceX96,
            TickMath.getSqrtPriceAtTick(positionUnderlying_.lowerTick),
            TickMath.getSqrtPriceAtTick(positionUnderlying_.upperTick),
            positionState.liquidity
        );
    }

    /// @notice Computes the token0 and token1 value for a given amount of liquidity, the current
    /// pool prices and the prices at the tick boundaries
    function getAmountsForDelta(
        uint160 sqrtRatioX96,
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        int128 liquidity
    ) public pure returns (uint256 amount0, uint256 amount1) {
        if (sqrtRatioAX96 > sqrtRatioBX96) {
            (sqrtRatioAX96, sqrtRatioBX96) =
                (sqrtRatioBX96, sqrtRatioAX96);
        }

        if (sqrtRatioX96 < sqrtRatioAX96) {
            amount0 = SafeCast.toUint256(
                SqrtPriceMath.getAmount0Delta(
                    sqrtRatioAX96, sqrtRatioBX96, liquidity
                )
            );
        } else if (sqrtRatioX96 < sqrtRatioBX96) {
            amount0 = SafeCast.toUint256(
                SqrtPriceMath.getAmount0Delta(
                    sqrtRatioX96, sqrtRatioBX96, liquidity
                )
            );
            amount1 = SafeCast.toUint256(
                SqrtPriceMath.getAmount1Delta(
                    sqrtRatioAX96, sqrtRatioX96, liquidity
                )
            );
        } else {
            amount1 = SafeCast.toUint256(
                SqrtPriceMath.getAmount1Delta(
                    sqrtRatioAX96, sqrtRatioBX96, liquidity
                )
            );
        }
    }

    function _getFeesOwned(
        Position.State memory self,
        uint256 feeGrowthInside0X128,
        uint256 feeGrowthInside1X128
    ) internal view returns (uint256 feesOwed0, uint256 feesOwed1) {
        unchecked {
            feesOwed0 = FullMath.mulDiv(
                feeGrowthInside0X128 - self.feeGrowthInside0LastX128,
                self.liquidity,
                FixedPoint128.Q128
            );
            feesOwed1 = FullMath.mulDiv(
                feeGrowthInside1X128 - self.feeGrowthInside1LastX128,
                self.liquidity,
                FixedPoint128.Q128
            );
        }
    }

    // solhint-disable-next-line function-max-lines
    function _totalUnderlyingWithFees(
        UnderlyingPayload memory underlyingPayload_,
        uint160 sqrtPriceX96_
    )
        private
        view
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 fee0,
            uint256 fee1
        )
    {
        for (uint256 i; i < underlyingPayload_.ranges.length; i++) {
            {
                (uint256 a0, uint256 a1, uint256 f0, uint256 f1) =
                underlying(
                    RangeData({
                        self: underlyingPayload_.self,
                        range: underlyingPayload_.ranges[i],
                        poolManager: underlyingPayload_.poolManager
                    }),
                    sqrtPriceX96_
                );
                amount0 += a0;
                amount1 += a1;
                fee0 += f0;
                fee1 += f1;
            }
        }

        amount0 += fee0 + underlyingPayload_.leftOver0;
        amount1 += fee1 + underlyingPayload_.leftOver1;
    }
}
