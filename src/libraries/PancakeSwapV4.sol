// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {IPancakeSwapV4StandardModule} from
    "../interfaces/IPancakeSwapV4StandardModule.sol";
import {NATIVE_COIN} from "../constants/CArrakis.sol";
import {
    UnderlyingPayload,
    RangeData,
    PositionUnderlying,
    Range as PoolRange,
    ComputeFeesPayload,
    GetFeesPayload
} from "../structs/SPancakeSwapV4.sol";

import {PoolKey} from "@pancakeswap/v4-core/src/types/PoolKey.sol";
import {PoolIdLibrary} from
    "@pancakeswap/v4-core/src/types/PoolId.sol";
import {
    BalanceDeltaLibrary,
    BalanceDelta
} from "@pancakeswap/v4-core/src/types/BalanceDelta.sol";
import {Hooks} from "@pancakeswap/v4-core/src/libraries/Hooks.sol";
import {IHooks} from "@pancakeswap/v4-core/src/interfaces/IHooks.sol";
import {Currency} from "@pancakeswap/v4-core/src/types/Currency.sol";
import {PoolId} from "@pancakeswap/v4-core/src/types/PoolId.sol";
import {
    ICLHooks,
    HOOKS_BEFORE_REMOVE_LIQUIDITY_OFFSET,
    HOOKS_AFTER_REMOVE_LIQUIDITY_OFFSET,
    HOOKS_AFTER_ADD_LIQUIDITY_OFFSET
} from "@pancakeswap/v4-core/src/pool-cl/interfaces/ICLHooks.sol";
import {FullMath} from
    "@pancakeswap/v4-core/src/pool-cl/libraries/FullMath.sol";
import {TickMath} from
    "@pancakeswap/v4-core/src/pool-cl/libraries/TickMath.sol";
import {FixedPoint128} from
    "@pancakeswap/v4-core/src/pool-cl/libraries/FixedPoint128.sol";
import {CLPosition} from
    "@pancakeswap/v4-core/src/pool-cl/libraries/CLPosition.sol";
import {Tick} from
    "@pancakeswap/v4-core/src/pool-cl/libraries/Tick.sol";

import {Position} from "@uniswap/v4-core/src/libraries/Position.sol";

import {SafeERC20} from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {LiquidityAmounts} from
    "@v3-lib-0.8/contracts/LiquidityAmounts.sol";

library PancakeSwapV4 {
    using PoolIdLibrary for PoolKey;
    using BalanceDeltaLibrary for BalanceDelta;
    using SafeERC20 for IERC20Metadata;
    using Address for address payable;
    using Hooks for bytes32;

    // #region public functions.

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

    // #endregion public functions.

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

    function _getLeftOvers(
        IPancakeSwapV4StandardModule self_,
        PoolKey memory poolKey_
    ) internal view returns (uint256 leftOver0, uint256 leftOver1) {
        leftOver0 = Currency.unwrap(poolKey_.currency0) == address(0)
            ? address(this).balance
            : IERC20Metadata(Currency.unwrap(poolKey_.currency0))
                .balanceOf(address(this));
        leftOver1 = IERC20Metadata(
            Currency.unwrap(poolKey_.currency1)
        ).balanceOf(address(this));
    }

    function _getPoolRanges(
        IPancakeSwapV4StandardModule.Range[] storage ranges_,
        PoolKey memory poolKey_
    ) internal view returns (PoolRange[] memory poolRanges) {
        uint256 length = ranges_.length;
        poolRanges = new PoolRange[](length);
        for (uint256 i; i < length; i++) {
            IPancakeSwapV4StandardModule.Range memory range =
                ranges_[i];
            poolRanges[i] = PoolRange({
                lowerTick: range.tickLower,
                upperTick: range.tickUpper,
                poolKey: poolKey_
            });
        }
    }

    function _checkTokens(
        PoolKey memory poolKey_,
        address token0_,
        address token1_,
        bool isInversed_
    ) internal pure {
        if (isInversed_) {
            /// @dev Currency.unwrap(poolKey_.currency1) == address(0) is not possible
            /// @dev because currency0 should be lower currency1.

            if (token0_ == NATIVE_COIN) {
                revert
                    IPancakeSwapV4StandardModule
                    .NativeCoinCannotBeToken1();
            } else if (Currency.unwrap(poolKey_.currency1) != token0_)
            {
                revert IPancakeSwapV4StandardModule.Currency1DtToken0(
                    Currency.unwrap(poolKey_.currency1), token0_
                );
            }

            if (token1_ == NATIVE_COIN) {
                if (Currency.unwrap(poolKey_.currency0) != address(0))
                {
                    revert
                        IPancakeSwapV4StandardModule
                        .Currency0DtToken1(
                        Currency.unwrap(poolKey_.currency0), token1_
                    );
                }
            } else if (Currency.unwrap(poolKey_.currency0) != token1_)
            {
                revert IPancakeSwapV4StandardModule.Currency0DtToken1(
                    Currency.unwrap(poolKey_.currency0), token1_
                );
            }
        } else {
            if (token0_ == NATIVE_COIN) {
                if (Currency.unwrap(poolKey_.currency0) != address(0))
                {
                    revert
                        IPancakeSwapV4StandardModule
                        .Currency0DtToken0(
                        Currency.unwrap(poolKey_.currency0), token0_
                    );
                }
            } else if (Currency.unwrap(poolKey_.currency0) != token0_)
            {
                revert IPancakeSwapV4StandardModule.Currency0DtToken0(
                    Currency.unwrap(poolKey_.currency0), token0_
                );
            }

            if (token1_ == NATIVE_COIN) {
                revert
                    IPancakeSwapV4StandardModule
                    .NativeCoinCannotBeToken1();
            } else if (Currency.unwrap(poolKey_.currency1) != token1_)
            {
                revert IPancakeSwapV4StandardModule.Currency1DtToken1(
                    Currency.unwrap(poolKey_.currency1), token1_
                );
            }
        }
    }

    function _checkPermissions(
        PoolKey memory poolKey_
    ) internal {
        ICLHooks hooks = ICLHooks(address(poolKey_.hooks));
        if (
            poolKey_.parameters.shouldCall(
                HOOKS_BEFORE_REMOVE_LIQUIDITY_OFFSET, hooks
            )
                || poolKey_.parameters.shouldCall(
                    HOOKS_AFTER_REMOVE_LIQUIDITY_OFFSET, hooks
                )
                || poolKey_.parameters.shouldCall(
                    HOOKS_AFTER_ADD_LIQUIDITY_OFFSET, hooks
                )
        ) {
            revert
                IPancakeSwapV4StandardModule
                .NoRemoveOrAddLiquidityHooks();
        }
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
