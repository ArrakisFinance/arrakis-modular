// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {UnderlyingPayload, ComputeFeesPayload, PositionUnderlying, GetFeesPayload, RangeData} from "../structs/SUniswapV4.sol";
import {PIPS} from "../constants/CArrakis.sol";

import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {FullMath} from "@uniswap/v4-core/src/libraries/FullMath.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {Position} from "@uniswap/v4-core/src/libraries/Position.sol";
import {FixedPoint128} from "@uniswap/v4-core/src/libraries/FixedPoint128.sol";
import {SqrtPriceMath} from "@uniswap/v4-core/src/libraries/SqrtPriceMath.sol";
import {PoolIdLibrary, PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {LiquidityAmounts} from "@uniswap/v4-periphery/contracts/libraries/LiquidityAmounts.sol";

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library UnderlyingV4 {
    // solhint-disable-next-line function-max-lines
    function totalUnderlyingForMint(
        UnderlyingPayload memory underlyingPayload_,
        uint256 proportion_,
        address metaVault_
    ) public view returns (uint256 amount0, uint256 amount1) {
        uint256 fee0;
        uint256 fee1;
        for (uint256 i; i < underlyingPayload_.ranges.length; i++) {
            {
                (
                    uint256 a0,
                    uint256 a1,
                    uint256 f0,
                    uint256 f1
                ) = underlyingMint(
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

        uint256 leftOver0;
        uint256 leftOver1;
        if (underlyingPayload_.ranges.length > 0) {
            leftOver0 = SafeCast.toUint256(
                underlyingPayload_.poolManager.currencyDelta(
                    address(this),
                    underlyingPayload_.ranges[0].poolKey.currency0
                )
            );
            leftOver1 = SafeCast.toUint256(
                underlyingPayload_.poolManager.currencyDelta(
                    address(this),
                    underlyingPayload_.ranges[0].poolKey.currency1
                )
            );
        }

        amount0 += FullMath.mulDivRoundingUp(
            proportion_,
            fee0 +
                IERC20(underlyingPayload_.token0).balanceOf(
                    underlyingPayload_.self
                ) +
                IERC20(underlyingPayload_.token0).balanceOf(metaVault_) +
                leftOver0,
            PIPS
        );
        amount1 += FullMath.mulDivRoundingUp(
            proportion_,
            fee1 +
                IERC20(underlyingPayload_.token1).balanceOf(
                    underlyingPayload_.self
                ) +
                IERC20(underlyingPayload_.token1).balanceOf(metaVault_) +
                leftOver1,
            PIPS
        );
    }

    // solhint-disable-next-line function-max-lines
    function totalUnderlyingWithFees(
        UnderlyingPayload memory underlyingPayload_
    )
        public
        view
        returns (uint256 amount0, uint256 amount1, uint256 fee0, uint256 fee1)
    {
        return _totalUnderlyingWithFees(underlyingPayload_, 0);
    }

    function totalUnderlyingAtPriceWithFees(
        UnderlyingPayload memory underlyingPayload_,
        uint160 sqrtPriceX96_
    )
        public
        view
        returns (uint256 amount0, uint256 amount1, uint256 fee0, uint256 fee1)
    {
        return _totalUnderlyingWithFees(underlyingPayload_, sqrtPriceX96_);
    }

    function underlying(
        RangeData memory underlying_,
        uint160 sqrtPriceX96_
    )
        public
        view
        returns (uint256 amount0, uint256 amount1, uint256 fee0, uint256 fee1)
    {
        (uint160 sqrtPriceX96, , ) = underlying_.poolManager.getSlot0(
            PoolIdLibrary.toId(underlying_.range.poolKey)
        );
        PositionUnderlying memory positionUnderlying = PositionUnderlying({
            sqrtPriceX96: sqrtPriceX96_ > 0 ? sqrtPriceX96_ : sqrtPriceX96,
            poolManager: underlying_.poolManager,
            poolKey: underlying_.range.poolKey,
            self: underlying_.self,
            lowerTick: underlying_.range.lowerTick,
            upperTick: underlying_.range.upperTick
        });
        (amount0, amount1, fee0, fee1) = getUnderlyingBalances(
            positionUnderlying
        );
    }

    function underlyingMint(
        RangeData memory underlying_,
        uint256 proportion_
    )
        public
        view
        returns (uint256 amount0, uint256 amount1, uint256 fee0, uint256 fee1)
    {
        (uint160 sqrtPriceX96, , ) = underlying_.poolManager.getSlot0(
            PoolIdLibrary.toId(underlying_.range.poolKey)
        );
        PositionUnderlying memory positionUnderlying = PositionUnderlying({
            sqrtPriceX96: sqrtPriceX96,
            poolManager: underlying_.poolManager,
            poolKey: underlying_.range.poolKey,
            self: underlying_.self,
            lowerTick: underlying_.range.lowerTick,
            upperTick: underlying_.range.upperTick
        });
        (amount0, amount1, fee0, fee1) = getUnderlyingBalancesMint(
            positionUnderlying,
            proportion_
        );
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
        Position.Info memory positionInfo;
        {
            PoolId poolId = PoolIdLibrary.toId(positionUnderlying_.poolKey);

            // compute current fees earned
            (
                uint256 feeGrowthInside0X128,
                uint256 feeGrowthInside1X128
            ) = _getFeeGrowthInside(
                    poolId,
                    positionUnderlying_.poolManager,
                    positionUnderlying_.lowerTick,
                    positionUnderlying_.upperTick
                );
            positionInfo = positionUnderlying_.poolManager.getPosition(
                poolId,
                positionUnderlying_.self,
                positionUnderlying_.lowerTick,
                positionUnderlying_.upperTick
            );
            (fee0, fee1) = _getFeesOwned(
                positionInfo,
                feeGrowthInside0X128,
                feeGrowthInside1X128
            );
        }

        // compute current holdings from liquidity
        (amount0Current, amount1Current) = getAmountsForDelta(
            positionUnderlying_.sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(positionUnderlying_.lowerTick),
            TickMath.getSqrtRatioAtTick(positionUnderlying_.upperTick),
            SafeCast.toInt128(
                SafeCast.toInt256(
                    FullMath.mulDiv(
                        uint256(positionInfo.liquidity),
                        proportion_,
                        PIPS
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
        PoolId poolId = PoolIdLibrary.toId(positionUnderlying_.poolKey);

        // compute current fees earned
        (
            uint256 feeGrowthInside0X128,
            uint256 feeGrowthInside1X128
        ) = _getFeeGrowthInside(
                poolId,
                positionUnderlying_.poolManager,
                positionUnderlying_.lowerTick,
                positionUnderlying_.upperTick
            );
        Position.Info memory positionInfo = positionUnderlying_
            .poolManager
            .getPosition(
                poolId,
                positionUnderlying_.self,
                positionUnderlying_.lowerTick,
                positionUnderlying_.upperTick
            );
        (fee0, fee1) = _getFeesOwned(
            positionInfo,
            feeGrowthInside0X128,
            feeGrowthInside1X128
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

    /// @notice Computes the token0 and token1 value for a given amount of liquidity, the current
    /// pool prices and the prices at the tick boundaries
    function getAmountsForDelta(
        uint160 sqrtRatioX96,
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        int128 liquidity
    ) public pure returns (uint256 amount0, uint256 amount1) {
        if (sqrtRatioAX96 > sqrtRatioBX96)
            (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

        if (sqrtRatioX96 < sqrtRatioAX96) {
            amount0 = SafeCast.toUint256(
                SqrtPriceMath.getAmount0Delta(
                    sqrtRatioAX96,
                    sqrtRatioBX96,
                    liquidity
                )
            );
        } else if (sqrtRatioX96 < sqrtRatioBX96) {
            amount0 = SafeCast.toUint256(
                SqrtPriceMath.getAmount0Delta(
                    sqrtRatioX96,
                    sqrtRatioBX96,
                    liquidity
                )
            );
            amount1 = SafeCast.toUint256(
                SqrtPriceMath.getAmount1Delta(
                    sqrtRatioAX96,
                    sqrtRatioX96,
                    liquidity
                )
            );
        } else {
            amount1 = SafeCast.toUint256(
                SqrtPriceMath.getAmount1Delta(
                    sqrtRatioAX96,
                    sqrtRatioBX96,
                    liquidity
                )
            );
        }
    }

    // solhint-disable-next-line function-max-lines
    function computeProportion(
        uint256 current0_,
        uint256 current1_,
        uint256 amount0Max_,
        uint256 amount1Max_
    ) public pure returns (uint256 proportion) {
        // compute proportional amount of tokens to mint
        if (current0_ == 0 && current1_ > 0) {
            proportion = FullMath.mulDiv(amount1Max_, PIPS, current1_);
        } else if (current1_ == 0 && current0_ > 0) {
            proportion = FullMath.mulDiv(amount0Max_, PIPS, current0_);
        } else if (current0_ > 0 && current1_ > 0) {
            uint256 amount0Mint = FullMath.mulDiv(amount0Max_, PIPS, current0_);
            uint256 amount1Mint = FullMath.mulDiv(amount1Max_, PIPS, current1_);
            require(
                amount0Mint > 0 && amount1Mint > 0,
                "ArrakisVaultV2: mint 0"
            );

            proportion = amount0Mint < amount1Mint ? amount0Mint : amount1Mint;
        } else {
            revert("ArrakisVaultV2: panic");
        }
    }

    struct FeeGrowthInside {
        uint256 feeGrowthOutside0X128Lower;
        uint256 feeGrowthOutside1X128Lower;
        uint256 feeGrowthOutside0X128Upper;
        uint256 feeGrowthOutside1X128Upper;
        uint256 feeGrowthGlobal0X128;
        uint256 feeGrowthGlobal1X128;
        int24 tickCurrent;
    }

    function _getFeeGrowthInside(
        PoolId poolId_,
        IPoolManager poolManager_,
        int24 tickLower_,
        int24 tickUpper_
    )
        internal
        view
        returns (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128)
    {
        FeeGrowthInside memory feeGrowthInside;

        {
            uint256 POOL_SLOT = 6;
            bytes32 poolId = PoolId.unwrap(poolId_);

            // #region tickInfo Lower tick.
            {
                bytes memory tILower = poolManager_.extsload(
                    bytes32(
                        uint256(
                            keccak256(
                                abi.encode(
                                    tickLower_,
                                    bytes32(
                                        uint256(
                                            keccak256(
                                                abi.encode(poolId, POOL_SLOT)
                                            )
                                        ) + 4
                                    )
                                )
                            )
                        )
                    ),
                    3
                );

                (
                    ,
                    feeGrowthInside.feeGrowthOutside0X128Lower,
                    feeGrowthInside.feeGrowthOutside1X128Lower
                ) = abi.decode(tILower, (uint256, uint256, uint256));
            }
            // #endregion tickInfo Lower tick.

            // #region tickInfo Upper tick.
            {
                bytes memory tIUpper = poolManager_.extsload(
                    bytes32(
                        uint256(
                            keccak256(
                                abi.encode(
                                    tickUpper_,
                                    bytes32(
                                        uint256(
                                            keccak256(
                                                abi.encode(poolId, POOL_SLOT)
                                            )
                                        ) + 4
                                    )
                                )
                            )
                        )
                    ),
                    3
                );

                (
                    ,
                    feeGrowthInside.feeGrowthOutside0X128Upper,
                    feeGrowthInside.feeGrowthOutside1X128Upper
                ) = abi.decode(tIUpper, (uint256, uint256, uint256));
            }
            // #endregion tickInfo Upper tick.
            // #region get slot0.

            (, feeGrowthInside.tickCurrent, ) = poolManager_.getSlot0(
                poolId_
            );

            // #endregion get slot0.
            // #region pool global fees.

            {
                bytes memory globalFee = poolManager_.extsload(
                    bytes32(
                        uint256(keccak256(abi.encode(poolId, POOL_SLOT))) + 1
                    ),
                    2
                );

                (
                    feeGrowthInside.feeGrowthGlobal0X128,
                    feeGrowthInside.feeGrowthGlobal1X128
                ) = abi.decode(globalFee, (uint256, uint256));
            }

            // #endregion pool global fees.
        }

        unchecked {
            if (feeGrowthInside.tickCurrent < tickLower_) {
                feeGrowthInside0X128 =
                    feeGrowthInside.feeGrowthOutside0X128Lower -
                    feeGrowthInside.feeGrowthOutside0X128Upper;
                feeGrowthInside1X128 =
                    feeGrowthInside.feeGrowthOutside1X128Lower -
                    feeGrowthInside.feeGrowthOutside1X128Upper;
            } else if (feeGrowthInside.tickCurrent >= tickUpper_) {
                feeGrowthInside0X128 =
                    feeGrowthInside.feeGrowthOutside0X128Upper -
                    feeGrowthInside.feeGrowthOutside0X128Lower;
                feeGrowthInside1X128 =
                    feeGrowthInside.feeGrowthOutside1X128Upper -
                    feeGrowthInside.feeGrowthOutside1X128Lower;
            } else {
                feeGrowthInside0X128 =
                    feeGrowthInside.feeGrowthGlobal0X128 -
                    feeGrowthInside.feeGrowthOutside0X128Lower -
                    feeGrowthInside.feeGrowthOutside0X128Upper;
                feeGrowthInside1X128 =
                    feeGrowthInside.feeGrowthGlobal1X128 -
                    feeGrowthInside.feeGrowthOutside1X128Lower -
                    feeGrowthInside.feeGrowthOutside1X128Upper;
            }
        }
    }

    function _getFeesOwned(
        Position.Info memory self,
        uint256 feeGrowthInside0X128,
        uint256 feeGrowthInside1X128
    ) internal pure returns (uint256 feesOwed0, uint256 feesOwed1) {
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
        returns (uint256 amount0, uint256 amount1, uint256 fee0, uint256 fee1)
    {
        for (uint256 i; i < underlyingPayload_.ranges.length; i++) {
            {
                (uint256 a0, uint256 a1, uint256 f0, uint256 f1) = underlying(
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

        uint256 leftOver0;
        uint256 leftOver1;
        if (underlyingPayload_.ranges.length > 0) {
            leftOver0 = SafeCast.toUint256(
                underlyingPayload_.poolManager.currencyDelta(
                    address(this),
                    underlyingPayload_.ranges[0].poolKey.currency0
                )
            );
            leftOver1 = SafeCast.toUint256(
                underlyingPayload_.poolManager.currencyDelta(
                    address(this),
                    underlyingPayload_.ranges[0].poolKey.currency1
                )
            );
        }

        amount0 +=
            fee0 +
            IERC20(underlyingPayload_.token0).balanceOf(
                underlyingPayload_.self
            ) +
            leftOver0;
        amount1 +=
            fee1 +
            IERC20(underlyingPayload_.token1).balanceOf(
                underlyingPayload_.self
            ) +
            leftOver1;
    }
}
