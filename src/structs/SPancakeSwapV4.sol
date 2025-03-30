// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ICLPoolManager} from
    "@pancakeswap/v4-core/src/pool-cl/interfaces/ICLPoolManager.sol";
import {PoolKey} from "@pancakeswap/v4-core/src/types/PoolKey.sol";
import {PoolId} from "@pancakeswap/v4-core/src/types/PoolId.sol";

struct SwapPayload {
    bytes payload;
    address router;
    uint256 amountIn;
    uint256 expectedMinReturn;
    bool zeroForOne;
}

struct RangeData {
    address self;
    Range range;
    ICLPoolManager poolManager;
}

struct Range {
    int24 lowerTick;
    int24 upperTick;
    PoolKey poolKey;
}

struct UnderlyingPayload {
    Range[] ranges;
    ICLPoolManager poolManager;
    address self;
    uint256 leftOver0;
    uint256 leftOver1;
}

struct PositionUnderlying {
    uint160 sqrtPriceX96;
    ICLPoolManager poolManager;
    PoolKey poolKey;
    address self;
    int24 tick;
    int24 lowerTick;
    int24 upperTick;
}

struct ComputeFeesPayload {
    uint256 feeGrowthInsideLast;
    uint256 feeGrowthOutsideLower;
    uint256 feeGrowthOutsideUpper;
    uint256 feeGrowthGlobal;
    PoolId poolId;
    ICLPoolManager poolManager;
    uint128 liquidity;
    int24 tick;
    int24 lowerTick;
    int24 upperTick;
}

struct GetFeesPayload {
    uint256 feeGrowthInside0Last;
    uint256 feeGrowthInside1Last;
    PoolId poolId;
    ICLPoolManager poolManager;
    uint128 liquidity;
    int24 tick;
    int24 lowerTick;
    int24 upperTick;
}