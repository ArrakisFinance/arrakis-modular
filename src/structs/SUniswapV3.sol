// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IUniswapV3Pool} from "../interfaces/IUniswapV3Pool.sol";
import {INonfungiblePositionManager} from
    "../interfaces/INonfungiblePositionManager.sol";

struct Range {
    int24 lowerTick;
    int24 upperTick;
}

struct PositionLiquidity {
    uint128 liquidity;
    Range range;
}

struct Rebalance {
    PositionLiquidity[] burns;
    PositionLiquidity[] mints;
    SwapPayload swap;
    uint256 minBurn0;
    uint256 minBurn1;
    uint256 minDeposit0;
    uint256 minDeposit1;
}

struct UnderlyingPayloadV3 {
    Range[] ranges;
    address pool;
    address self;
    uint256 leftOver0;
    uint256 leftOver1;
    address token0;
    address token1;
}

struct PositionUnderlying {
    address nftPositionManager;
    address factory;
    uint256 tokenId;
}

struct PositionUnderlyingV3 {
    bytes32 positionId;
    uint160 sqrtPriceX96;
    address pool;
    int24 tick;
    int24 lowerTick;
    int24 upperTick;
}

struct UnderlyingPayload {
    uint256[] tokenIds;
    address nftPositionManager;
    address factory;
    uint256 leftOver0;
    uint256 leftOver1;
    address module;
}

struct GetFeesPayload {
    uint256 feeGrowthInside0Last;
    uint256 feeGrowthInside1Last;
    address pool;
    uint128 liquidity;
    int24 tick;
    int24 lowerTick;
    int24 upperTick;
}

struct ComputeFeesPayload {
    uint256 feeGrowthInsideLast;
    uint256 feeGrowthOutsideLower;
    uint256 feeGrowthOutsideUpper;
    uint256 feeGrowthGlobal;
    address pool;
    uint128 liquidity;
    int24 tick;
    int24 lowerTick;
    int24 upperTick;
}

struct ModifyPosition {
    uint256 tokenId;
    uint256 proportion;
}

struct SwapPayload {
    bytes payload;
    address router;
    uint256 amountIn;
    uint256 expectedMinReturn;
    bool zeroForOne;
}

struct RebalanceParams {
    ModifyPosition[] decreasePositions;
    ModifyPosition[] increasePositions;
    SwapPayload swapPayload;
    INonfungiblePositionManager.MintParams[] mintParams;
    uint256 minBurn0;
    uint256 minBurn1;
    uint256 minDeposit0;
    uint256 minDeposit1;
}

struct RangeData {
    address self;
    Range range;
    address pool;
}
