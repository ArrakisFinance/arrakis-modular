// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPoolManager} from
    "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";

struct UnderlyingPayload {
    Range[] ranges;
    IPoolManager poolManager;
    address self;
    uint256 leftOver0;
    uint256 leftOver1;
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

struct RangeMintBurn {
    Range range;
    uint128 liquidity;
}

struct ComputeFeesPayload {
    uint256 feeGrowthInsideLast;
    uint256 feeGrowthOutsideLower;
    uint256 feeGrowthOutsideUpper;
    uint256 feeGrowthGlobal;
    IPoolManager poolManager;
    PoolKey poolKey;
    uint128 liquidity;
    int24 tick;
    int24 lowerTick;
    int24 upperTick;
}

struct GetFeesPayload {
    uint256 feeGrowthInside0Last;
    uint256 feeGrowthInside1Last;
    IPoolManager poolManager;
    PoolKey poolKey;
    uint128 liquidity;
    int24 tick;
    int24 lowerTick;
    int24 upperTick;
}

struct PositionUnderlying {
    uint160 sqrtPriceX96;
    IPoolManager poolManager;
    PoolKey poolKey;
    address self;
    int24 lowerTick;
    int24 upperTick;
}

struct Withdraw {
    address receiver;
    uint256 proportion;
    uint256 amount0;
    uint256 amount1;
    uint256 fee0;
    uint256 fee1;
}

struct Deposit {
    address depositor;
    uint256 proportion;
    uint256 value;
    bool notFirstDeposit;
    uint256 fee0;
    uint256 fee1;
    uint256 leftOverToMint0;
    uint256 leftOverToMint1;
}

struct RebalanceResult {
        uint256 amount0Minted;
        uint256 amount1Minted;
        uint256 amount0Burned;
        uint256 amount1Burned;
        uint256 fee0;
        uint256 fee1;
        uint256 managerFee0;
        uint256 managerFee1;
}

struct SwapPayload {
    bytes payload;
    address router;
    uint256 amountIn;
    uint256 expectedMinReturn;
    bool zeroForOne;
}

struct SwapBalances {
    uint256 initBalance;
    uint256 balance;
}