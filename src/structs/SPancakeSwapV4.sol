// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ICLPoolManager} from
    "@pancakeswap/v4-core/src/pool-cl/interfaces/ICLPoolManager.sol";
import {PoolKey} from "@pancakeswap/v4-core/src/types/PoolKey.sol";

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
    IPoolManager poolManager;
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
    IPoolManager poolManager;
    PoolKey poolKey;
    address self;
    int24 lowerTick;
    int24 upperTick;
}