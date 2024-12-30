// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IUniswapV3Pool} from "../interfaces/IUniswapV3Pool.sol";
import {INonfungiblePositionManager} from "../interfaces/INonfungiblePositionManager.sol";

struct Range {
    int24 lowerTick;
    int24 upperTick;
    uint24 feeTier;
}

struct PositionUnderlying {
    address nftPositionManager;
    address factory;
    uint256 tokenId;
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
    IUniswapV3Pool pool;
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
    ModifyPosition[] modifyPositions;
    SwapPayload swapPayload;
    INonfungiblePositionManager.MintParams[] mintParams;
    uint256 minBurn0;
    uint256 minBurn1;
    uint256 minDeposit0;
    uint256 minDeposit1;
}