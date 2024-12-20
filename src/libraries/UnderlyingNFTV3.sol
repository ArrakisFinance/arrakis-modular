// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {INonfungiblePositionManager} from
    "../interfaces/INonfungiblePositionManager.sol";
import {IUniswapV3Pool} from "../interfaces/IUniswapV3Pool.sol";
import {IUniswapV3Factory} from "../interfaces/IUniswapV3Factory.sol";
import {
    PositionUnderlying
} from "../structs/SUniswapV3.sol";

import {TickMath} from "@v3-lib-0.8/contracts/TickMath.sol";
import {LiquidityAmounts} from
    "@v3-lib-0.8/contracts/LiquidityAmounts.sol";

library UnderlyingNFTV3 {
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
            uint256 amount1
        )
    {
        PositionUnderlying memory positionUnderlying =
        PositionUnderlying({
            nftPositionManager: nftPositionManager_,
            factory: factory_,
            tokenId: tokenId_
        });
        (amount0, amount1) =
            getUnderlyingBalances(positionUnderlying, sqrtPriceX96_);
    }

    function getUnderlyingBalances(
        PositionUnderlying memory positionUnderlying_,
        uint160 sqrtPriceX96_
    )
        public
        view
        returns (
            uint256 amount0Current,
            uint256 amount1Current
        )
    {
        (uint160 sqrtPriceX96, int24 lowerTick, int24 upperTick, uint128 liquidity) =
            getData(positionUnderlying_);

        // compute current holdings from liquidity
        (amount0Current, amount1Current) = LiquidityAmounts
            .getAmountsForLiquidity(
            sqrtPriceX96_ > 0 ? sqrtPriceX96_ : sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(lowerTick),
            TickMath.getSqrtRatioAtTick(upperTick),
            liquidity
        );
    }

    function getData(
        PositionUnderlying memory positionUnderlying_
    )
        public
        view
        returns (
            uint160 sqrtPriceX96,
            int24 lowerTick,
            int24 upperTick,
            uint128 liquidity
        )
    {
        address token0;
        address token1;
        int24 tickSpacing;
        (
            ,
            ,
            token0,
            token1,
            tickSpacing,
            lowerTick,
            upperTick,
            liquidity,
            ,
            ,
            ,
        ) = INonfungiblePositionManager(
            positionUnderlying_.nftPositionManager
        ).positions(positionUnderlying_.tokenId);

        IUniswapV3Pool pool = IUniswapV3Pool(
            computeAddress(
                positionUnderlying_.factory,
                token0,
                token1,
                tickSpacing
            )
        );

        (sqrtPriceX96, ,,,,) =
            pool.slot0();
    }

    function computeAddress(
        address factory,
        address token0,
        address token1,
        int24 tickSpacing
    ) internal view returns (address pool) {
        return IUniswapV3Factory(factory).getPool(
            token0, token1, tickSpacing
        );
    }
}
