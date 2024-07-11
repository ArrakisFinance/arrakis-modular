// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

struct Deal {
    address caller;
    address collateralToken;
    uint256 collateralAmount;
    address feeFreeSwapper;
    uint256 feeGeneration0;
    uint256 feeGeneration1;
    uint160 finalSqrtPriceX96;
    uint256 finalAmount0;
    uint256 finalAmount1;
    uint256 tips;
    uint256 nonce;
}
