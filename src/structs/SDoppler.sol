// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IPoolManager} from
    "@uniswap/v4-core/src/interfaces/IPoolManager.sol";

struct DopplerData {
    uint256 numTokensToSell;
    uint256 minimumProceeds;
    uint256 maximumProceeds;
    uint256 startingTime;
    uint256 endingTime;
    int24 startingTick;
    int24 endingTick;
    uint256 epochLength;
    int24 gamma;
    bool isToken0;
    uint256 numPDSlugs;
}

struct Position {
    int24 tickLower;
    int24 tickUpper;
    uint128 liquidity;
    uint8 salt;
}