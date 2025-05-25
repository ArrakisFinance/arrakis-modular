// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {
    UnderlyingPayload,
    RangeData,
    PositionUnderlying,
    ComputeFeesPayload,
    GetFeesPayload
} from "../structs/SPancakeSwapV4.sol";
import {IArrakisLPModule} from "../interfaces/IArrakisLPModule.sol";
import {BASE, PIPS} from "../constants/CArrakis.sol";

import {PoolKey} from "@pancakeswap/v4-core/src/types/PoolKey.sol";
import {
    PoolId,
    PoolIdLibrary
} from "@pancakeswap/v4-core/src/types/PoolId.sol";
import {FullMath} from
    "@pancakeswap/v4-core/src/pool-cl/libraries/FullMath.sol";
import {TickMath} from
    "@pancakeswap/v4-core/src/pool-cl/libraries/TickMath.sol";
import {Tick} from
    "@pancakeswap/v4-core/src/pool-cl/libraries/Tick.sol";
import {CLPosition} from
    "@pancakeswap/v4-core/src/pool-cl/libraries/CLPosition.sol";
import {SqrtPriceMath} from
    "@pancakeswap/v4-core/src/pool-cl/libraries/SqrtPriceMath.sol";

import {SafeCast} from
    "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {LiquidityAmounts} from
    "@v3-lib-0.8/contracts/LiquidityAmounts.sol";

library PancakeUnderlyingV4 {
    using PoolIdLibrary for PoolKey;

    // #region public functions underlying.

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

        uint256 managerFeePIPS =
            IArrakisLPModule(underlyingPayload_.self).managerFeePIPS();

        fee0 = fee0 - FullMath.mulDiv(fee0, managerFeePIPS, PIPS);

        fee1 = fee1 - FullMath.mulDiv(fee1, managerFeePIPS, PIPS);

        amount0 += FullMath.mulDivRoundingUp(
            proportion_, fee0 + underlyingPayload_.leftOver0, BASE
        );
        amount1 += FullMath.mulDivRoundingUp(
            proportion_, fee1 + underlyingPayload_.leftOver1, BASE
        );
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
        int24 tick;
        uint160 sqrtPriceX96;
        (sqrtPriceX96, tick,,) = underlying_.poolManager.getSlot0(
            PoolIdLibrary.toId(underlying_.range.poolKey)
        );

        PositionUnderlying memory positionUnderlying =
        PositionUnderlying({
            sqrtPriceX96: sqrtPriceX96,
            poolManager: underlying_.poolManager,
            poolKey: underlying_.range.poolKey,
            self: underlying_.self,
            tick: tick,
            lowerTick: underlying_.range.lowerTick,
            upperTick: underlying_.range.upperTick
        });

        (amount0, amount1, fee0, fee1) =
            getUnderlyingBalancesMint(positionUnderlying, proportion_);
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
        int24 tick;
        if (sqrtPriceX96_ == 0) {
            (sqrtPriceX96_, tick,,) = underlying_.poolManager.getSlot0(
                PoolIdLibrary.toId(underlying_.range.poolKey)
            );
        } else {
            (, tick,,) = underlying_.poolManager.getSlot0(
                PoolIdLibrary.toId(underlying_.range.poolKey)
            );
        }

        PositionUnderlying memory positionUnderlying =
        PositionUnderlying({
            sqrtPriceX96: sqrtPriceX96_,
            poolManager: underlying_.poolManager,
            poolKey: underlying_.range.poolKey,
            self: underlying_.self,
            tick: tick,
            lowerTick: underlying_.range.lowerTick,
            upperTick: underlying_.range.upperTick
        });

        (amount0, amount1, fee0, fee1) =
            getUnderlyingBalances(positionUnderlying);
    }

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
        PoolId poolId = positionUnderlying_.poolKey.toId();

        // compute current fees earned
        CLPosition.Info memory positionInfo;
        positionInfo = positionUnderlying_.poolManager.getPosition(
            poolId,
            positionUnderlying_.self,
            positionUnderlying_.lowerTick,
            positionUnderlying_.upperTick,
            ""
        );
        (fee0, fee1) = _getFeesEarned(
            GetFeesPayload({
                feeGrowthInside0Last: positionInfo
                    .feeGrowthInside0LastX128,
                feeGrowthInside1Last: positionInfo
                    .feeGrowthInside1LastX128,
                poolId: poolId,
                poolManager: positionUnderlying_.poolManager,
                liquidity: positionInfo.liquidity,
                tick: positionUnderlying_.tick,
                lowerTick: positionUnderlying_.lowerTick,
                upperTick: positionUnderlying_.upperTick
            })
        );

        int128 liquidity = SafeCast.toInt128(
            SafeCast.toInt256(
                FullMath.mulDivRoundingUp(
                    uint256(positionInfo.liquidity), proportion_, BASE
                )
            )
        );

        // compute current holdings from liquidity
        (amount0Current, amount1Current) = getAmountsForDelta(
            positionUnderlying_.sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(positionUnderlying_.lowerTick),
            TickMath.getSqrtRatioAtTick(positionUnderlying_.upperTick),
            liquidity
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
        CLPosition.Info memory positionInfo;
        positionInfo = positionUnderlying_.poolManager.getPosition(
            poolId,
            positionUnderlying_.self,
            positionUnderlying_.lowerTick,
            positionUnderlying_.upperTick,
            ""
        );
        (fee0, fee1) = _getFeesEarned(
            GetFeesPayload({
                feeGrowthInside0Last: positionInfo
                    .feeGrowthInside0LastX128,
                feeGrowthInside1Last: positionInfo
                    .feeGrowthInside1LastX128,
                poolId: poolId,
                poolManager: positionUnderlying_.poolManager,
                liquidity: positionInfo.liquidity,
                tick: positionUnderlying_.tick,
                lowerTick: positionUnderlying_.lowerTick,
                upperTick: positionUnderlying_.upperTick
            })
        );

        // compute current holdings from liquidity
        (amount0Current, amount1Current) = LiquidityAmounts
            .getAmountsForLiquidity(
            positionUnderlying_.sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(positionUnderlying_.lowerTick),
            TickMath.getSqrtRatioAtTick(positionUnderlying_.upperTick),
            positionInfo.liquidity
        );
    }

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
                -SqrtPriceMath.getAmount0Delta(
                    sqrtRatioAX96, sqrtRatioBX96, liquidity
                )
            );
        } else if (sqrtRatioX96 < sqrtRatioBX96) {
            amount0 = SafeCast.toUint256(
                -SqrtPriceMath.getAmount0Delta(
                    sqrtRatioX96, sqrtRatioBX96, liquidity
                )
            );
            amount1 = SafeCast.toUint256(
                -SqrtPriceMath.getAmount1Delta(
                    sqrtRatioAX96, sqrtRatioX96, liquidity
                )
            );
        } else {
            amount1 = SafeCast.toUint256(
                -SqrtPriceMath.getAmount1Delta(
                    sqrtRatioAX96, sqrtRatioBX96, liquidity
                )
            );
        }
    }

    // #endregion public functions underlying.

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

    // solhint-disable-next-line function-max-lines
    function _getFeesEarned(
        GetFeesPayload memory feeInfo_
    ) private view returns (uint256 fee0, uint256 fee1) {
        Tick.Info memory lower = feeInfo_.poolManager.getPoolTickInfo(
            feeInfo_.poolId, feeInfo_.lowerTick
        );
        Tick.Info memory upper = feeInfo_.poolManager.getPoolTickInfo(
            feeInfo_.poolId, feeInfo_.upperTick
        );

        ComputeFeesPayload memory payload = ComputeFeesPayload({
            feeGrowthInsideLast: feeInfo_.feeGrowthInside0Last,
            feeGrowthOutsideLower: lower.feeGrowthOutside0X128,
            feeGrowthOutsideUpper: upper.feeGrowthOutside0X128,
            feeGrowthGlobal: 0,
            poolId: feeInfo_.poolId,
            poolManager: feeInfo_.poolManager,
            liquidity: feeInfo_.liquidity,
            tick: feeInfo_.tick,
            lowerTick: feeInfo_.lowerTick,
            upperTick: feeInfo_.upperTick
        });

        (payload.feeGrowthGlobal,) =
            feeInfo_.poolManager.getFeeGrowthGlobals(feeInfo_.poolId);

        fee0 = _computeFeesEarned(payload);
        payload.feeGrowthInsideLast = feeInfo_.feeGrowthInside1Last;
        payload.feeGrowthOutsideLower = lower.feeGrowthOutside1X128;
        payload.feeGrowthOutsideUpper = upper.feeGrowthOutside0X128;
        (, payload.feeGrowthGlobal) =
            feeInfo_.poolManager.getFeeGrowthGlobals(feeInfo_.poolId);
        fee1 = _computeFeesEarned(payload);
    }

    function _computeFeesEarned(
        ComputeFeesPayload memory computeFees_
    ) private pure returns (uint256 fee) {
        unchecked {
            // calculate fee growth below
            uint256 feeGrowthBelow;
            if (computeFees_.tick >= computeFees_.lowerTick) {
                feeGrowthBelow = computeFees_.feeGrowthOutsideLower;
            } else {
                feeGrowthBelow = computeFees_.feeGrowthGlobal
                    - computeFees_.feeGrowthOutsideLower;
            }

            // calculate fee growth above
            uint256 feeGrowthAbove;
            if (computeFees_.tick < computeFees_.upperTick) {
                feeGrowthAbove = computeFees_.feeGrowthOutsideUpper;
            } else {
                feeGrowthAbove = computeFees_.feeGrowthGlobal
                    - computeFees_.feeGrowthOutsideUpper;
            }

            uint256 feeGrowthInside = computeFees_.feeGrowthGlobal
                - feeGrowthBelow - feeGrowthAbove;
            fee = FullMath.mulDiv(
                computeFees_.liquidity,
                feeGrowthInside - computeFees_.feeGrowthInsideLast,
                0x100000000000000000000000000000000
            );
        }
    }
}
