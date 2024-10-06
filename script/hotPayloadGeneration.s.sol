// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";

contract HOTPayloadGeneration is Script {
    function setup() public {}

    function run() public {
        uint160 sqrtPriceX96 = 1945818020508295863450355172695;

        int24 tick = TickMath.getTickAtSqrtPrice(sqrtPriceX96);

        int24 tickLower = tick - 100;
        int24 tickUpper = tick + 100;

        uint160 sqrtPriceLower = TickMath.getSqrtPriceAtTick(tickLower);
        uint160 sqrtPriceUpper = TickMath.getSqrtPriceAtTick(tickUpper);

        console.log("Lower Price: %d", sqrtPriceLower);
        console.log("Upper Price: %d", sqrtPriceUpper);
    }
}