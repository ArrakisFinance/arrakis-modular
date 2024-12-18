// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {IArrakisLPModule} from "../interfaces/IArrakisLPModule.sol";
import {INonfungiblePositionManager} from
    "../interfaces/INonfungiblePositionManager.sol";
import {IUniswapV3Pool} from "../interfaces/IUniswapV3Pool.sol";
import {
    UnderlyingPayload,
    PositionUnderlying,
    GetFeesPayload,
    ComputeFeesPayload
} from "../structs/SUniswapV3.sol";
import {Position} from "./Position.sol";
import {PIPS} from "../constants/CArrakis.sol";

import {TickMath} from "@v3-lib-0.8/contracts/TickMath.sol";
import {FullMath} from "@v3-lib-0.8/contracts/FullMath.sol";
import {SqrtPriceMath} from "@v3-lib-0.8/contracts/SqrtPriceMath.sol";
import {LiquidityAmounts} from
    "@v3-lib-0.8/contracts/LiquidityAmounts.sol";

import {SafeCast} from
    "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// import {PositionValue} from
//     "@uniswap/v3-periphery/contracts/libraries/PositionValue.sol";

library UnderlyingNFTV3 {
    bytes32 internal constant POOL_INIT_CODE_HASH =
        0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

    function totalUnderlyingForMint(
        UnderlyingPayload calldata underlyingPayload_,
        uint256 mintAmount_,
        uint256 totalSupply_
    ) public view returns (uint256 amount0, uint256 amount1) {
        uint256 fee0;
        uint256 fee1;

        {
            uint256 length = underlyingPayload_.tokenIds.length;

            for (uint256 i; i < length;) {
                (uint256 a0, uint256 a1, uint256 f0, uint256 f1) =
                underlyingMint(
                    underlyingPayload_.tokenIds[i],
                    underlyingPayload_.nftPositionManager,
                    underlyingPayload_.factory,
                    mintAmount_,
                    totalSupply_
                );

                amount0 += a0;
                amount1 += a1;
                fee0 += f0;
                fee1 += f1;

                unchecked {
                    i += 1;
                }
            }
        }

        uint256 fee0After;
        uint256 fee1After;

        {
            uint256 managerFeePIPS = IArrakisLPModule(
                underlyingPayload_.module
            ).managerFeePIPS();

            (fee0After, fee1After) =
                subtractAdminFees(fee0, fee1, managerFeePIPS);
        }

        amount0 += FullMath.mulDivRoundingUp(
            mintAmount_,
            fee0After
                + IArrakisLPModule(underlyingPayload_.module).token0()
                    .balanceOf(underlyingPayload_.module)
                - IArrakisLPModule(underlyingPayload_.module)
                    .managerBalance0(),
            totalSupply_
        );
        amount1 += FullMath.mulDivRoundingUp(
            mintAmount_,
            fee1After
                + IArrakisLPModule(underlyingPayload_.module).token1()
                    .balanceOf(underlyingPayload_.module)
                - IArrakisLPModule(underlyingPayload_.module)
                    .managerBalance1(),
            totalSupply_
        );
    }

    // solhint-disable-next-line function-max-lines
    function totalUnderlyingWithFees(
        UnderlyingPayload calldata underlyingPayload_
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
        UnderlyingPayload calldata underlyingPayload_,
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
        uint256 tokenId_,
        address nftPositionManager_,
        address factory_,
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
        PositionUnderlying memory positionUnderlying =
        PositionUnderlying({
            nftPositionManager: nftPositionManager_,
            factory: factory_,
            tokenId: tokenId_
        });
        (amount0, amount1, fee0, fee1) =
            getUnderlyingBalances(positionUnderlying, sqrtPriceX96_);
    }

    function underlyingMint(
        uint256 tokenId_,
        address nftPositionManager_,
        address factory_,
        uint256 mintAmount_,
        uint256 totalSupply_
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
        PositionUnderlying memory positionUnderlying =
        PositionUnderlying({
            nftPositionManager: nftPositionManager_,
            factory: factory_,
            tokenId: tokenId_
        });
        (amount0, amount1, fee0, fee1) = getUnderlyingBalancesMint(
            positionUnderlying, mintAmount_, totalSupply_
        );
    }

    function getUnderlyingBalances(
        PositionUnderlying memory positionUnderlying_,
        uint160 sqrtPriceX96_
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
        uint160 sqrtPriceX96;

        GetFeesPayload memory getFeesPayload;
        uint256 tokensOwed0;
        uint256 tokensOwed1;
        (getFeesPayload, sqrtPriceX96, tokensOwed0, tokensOwed1) =
            getFeesPayloadData(positionUnderlying_);

        // compute current fees earned
        (fee0, fee1) = _getFeesEarned(getFeesPayload);

        // compute current holdings from liquidity
        (amount0Current, amount1Current) = LiquidityAmounts
            .getAmountsForLiquidity(
            sqrtPriceX96_ > 0 ? sqrtPriceX96_ : sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(getFeesPayload.lowerTick),
            TickMath.getSqrtRatioAtTick(getFeesPayload.upperTick),
            getFeesPayload.liquidity
        );

        fee0 += uint256(tokensOwed0);
        fee1 += uint256(tokensOwed1);
    }

    // solhint-disable-next-line function-max-lines
    function getUnderlyingBalancesMint(
        PositionUnderlying memory positionUnderlying_,
        uint256 mintAmount_,
        uint256 totalSupply_
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
        uint160 sqrtPriceX96;

        GetFeesPayload memory getFeesPayload;
        {
            uint256 tokensOwed0;
            uint256 tokensOwed1;

            (getFeesPayload, sqrtPriceX96, tokensOwed0, tokensOwed1) =
                getFeesPayloadData(positionUnderlying_);

            // compute current fees earned
            (fee0, fee1) = _getFeesEarned(getFeesPayload);

            fee0 += uint256(tokensOwed0);
            fee1 += uint256(tokensOwed1);
        }

        // compute current holdings from liquidity
        (amount0Current, amount1Current) = getAmountsForDelta(
            sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(getFeesPayload.lowerTick),
            TickMath.getSqrtRatioAtTick(getFeesPayload.upperTick),
            SafeCast.toInt128(
                SafeCast.toInt256(
                    FullMath.mulDiv(
                        uint256(getFeesPayload.liquidity),
                        mintAmount_,
                        totalSupply_
                    )
                )
            )
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

    function subtractAdminFees(
        uint256 rawFee0_,
        uint256 rawFee1_,
        uint256 managerFeeBPS_
    ) public pure returns (uint256 fee0, uint256 fee1) {
        fee0 = rawFee0_ - ((rawFee0_ * (managerFeeBPS_)) / PIPS);
        fee1 = rawFee1_ - ((rawFee1_ * (managerFeeBPS_)) / PIPS);
    }

    function _totalUnderlyingWithFees(
        UnderlyingPayload calldata underlyingPayload_,
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
        for (uint256 i; i < underlyingPayload_.tokenIds.length;) {
            (uint256 a0, uint256 a1, uint256 f0, uint256 f1) =
            underlying(
                underlyingPayload_.tokenIds[i],
                underlyingPayload_.nftPositionManager,
                underlyingPayload_.factory,
                sqrtPriceX96_
            );
            amount0 += a0;
            amount1 += a1;
            fee0 += f0;
            fee1 += f1;

            unchecked {
                i += 1;
            }
        }

        uint256 fee0After;
        uint256 fee1After;

        {
            uint256 managerFeePIPS = IArrakisLPModule(
                underlyingPayload_.module
            ).managerFeePIPS();

            (fee0After, fee1After) =
                subtractAdminFees(fee0, fee1, managerFeePIPS);
        }

        amount0 += fee0After
            + IArrakisLPModule(underlyingPayload_.module).token0()
                .balanceOf(underlyingPayload_.module)
            - IArrakisLPModule(underlyingPayload_.module).managerBalance0(
            );
        amount1 += fee1After
            + IArrakisLPModule(underlyingPayload_.module).token1()
                .balanceOf(underlyingPayload_.module)
            - IArrakisLPModule(underlyingPayload_.module).managerBalance1(
            );
    }

    // solhint-disable-next-line function-max-lines
    function _getFeesEarned(
        GetFeesPayload memory feeInfo_
    ) private view returns (uint256 fee0, uint256 fee1) {
        (
            ,
            ,
            uint256 feeGrowthOutside0Lower,
            uint256 feeGrowthOutside1Lower,
            ,
            ,
            ,
        ) = feeInfo_.pool.ticks(feeInfo_.lowerTick);
        (
            ,
            ,
            uint256 feeGrowthOutside0Upper,
            uint256 feeGrowthOutside1Upper,
            ,
            ,
            ,
        ) = feeInfo_.pool.ticks(feeInfo_.upperTick);

        ComputeFeesPayload memory payload = ComputeFeesPayload({
            feeGrowthInsideLast: feeInfo_.feeGrowthInside0Last,
            feeGrowthOutsideLower: feeGrowthOutside0Lower,
            feeGrowthOutsideUpper: feeGrowthOutside0Upper,
            feeGrowthGlobal: feeInfo_.pool.feeGrowthGlobal0X128(),
            liquidity: feeInfo_.liquidity,
            tick: feeInfo_.tick,
            lowerTick: feeInfo_.lowerTick,
            upperTick: feeInfo_.upperTick
        });

        fee0 = _computeFeesEarned(payload);
        payload.feeGrowthInsideLast = feeInfo_.feeGrowthInside1Last;
        payload.feeGrowthOutsideLower = feeGrowthOutside1Lower;
        payload.feeGrowthOutsideUpper = feeGrowthOutside1Upper;
        payload.feeGrowthGlobal = feeInfo_.pool.feeGrowthGlobal1X128();
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

    function getFeesPayloadData(
        PositionUnderlying memory positionUnderlying_
    )
        public
        view
        returns (
            GetFeesPayload memory getFeesPayload,
            uint160 sqrtPriceX96,
            uint256 tokensOwed0,
            uint256 tokensOwed1
        )
    {
        address token0;
        address token1;
        uint24 fee;
        (
            ,
            ,
            ,
            ,
            ,
            getFeesPayload.lowerTick,
            getFeesPayload.upperTick,
            getFeesPayload.liquidity,
            getFeesPayload.feeGrowthInside0Last,
            getFeesPayload.feeGrowthInside1Last,
            ,
        ) = INonfungiblePositionManager(
            positionUnderlying_.nftPositionManager
        ).positions(positionUnderlying_.tokenId);

        (,, token0, token1, fee,,,,,, tokensOwed0, tokensOwed1) =
        INonfungiblePositionManager(
            positionUnderlying_.nftPositionManager
        ).positions(positionUnderlying_.tokenId);

        getFeesPayload.pool = IUniswapV3Pool(
            computeAddress(
                positionUnderlying_.factory, token0, token1, fee
            )
        );

        (sqrtPriceX96, getFeesPayload.tick,,,,,) =
            getFeesPayload.pool.slot0();
    }

    function computeAddress(
        address factory,
        address token0,
        address token1,
        uint24 fee
    ) internal pure returns (address pool) {
        require(token0 < token1);
        pool = address(
            SafeCast.toUint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            factory,
                            keccak256(abi.encode(token0, token1, fee)),
                            POOL_INIT_CODE_HASH
                        )
                    )
                )
            )
        );
    }
}
