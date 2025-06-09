// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import "@uniswap/v4-core/src/types/PoolKey.sol";
import "@uniswap/v4-core/src/types/Currency.sol";
import "@uniswap/v4-core/src/types/PoolId.sol";

address constant poolManagerAddress = 0x000000000004444c5dc75cB358380D2e3dE08A90;
address constant token0 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH
address constant token1 = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC
uint24 constant fee = 499;
int24 constant tickSpacing = 10;
address constant hooks = address(0);

uint160 constant startingSqrtPriceX96 = 79228162514264337593543950336; // 1:1 default

contract UniV4CreatePool is Script {
    function run() external {
        vm.startBroadcast();

        // Determine currency0 and currency1 based on address order
        Currency currency0;
        Currency currency1;
        if (uint160(token0) < uint160(token1)) {
            currency0 = Currency.wrap(token0);
            currency1 = Currency.wrap(token1);
        } else {
            currency0 = Currency.wrap(token1);
            currency1 = Currency.wrap(token0);
        }

        // Prepare the PoolKey
        PoolKey memory poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: fee,
            tickSpacing: tickSpacing,
            hooks: IHooks(hooks)
        });

        // Initialize the PoolManager contract
        IPoolManager poolManager = IPoolManager(poolManagerAddress);

        // Create the pool
        // @dev Potential custom errrors:
        //          0x7983c051 - pool already initialized
        poolManager.initialize(poolKey, startingSqrtPriceX96);

        // Compute the Pool ID
        PoolId poolId = poolKey.toId();

        // Log the pool details
        console.log("Pool created successfully!");
        console.log("Pool Id : ");
        console.logBytes32(PoolId.unwrap(poolId));
        console.log("Currency0:", address(Currency.unwrap(poolKey.currency0)));
        console.log("Currency1:", address(Currency.unwrap(poolKey.currency1)));
        console.log("Fee:", poolKey.fee);
        console.log("TickSpacing:", poolKey.tickSpacing);
        console.log("Hooks:", address(poolKey.hooks));

        vm.stopBroadcast();
    }
}

