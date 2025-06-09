// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import "@uniswap/v4-core/src/types/PoolKey.sol";
import "@uniswap/v4-core/src/types/Currency.sol";
import "@uniswap/v4-core/src/types/PoolId.sol";

/**
 * @title CreatePool
 * @notice Script that creates a Uniswap V4 pool with the specified user parameters
 */
contract CreatePool is Script {
    // ───────────── Immutable Environment ─────────────
    address constant POOL_MANAGER_ADDRESS = 
        0x498581fF718922c3f8e6A244956aF099B2652b2b;

    IPoolManager public immutable poolManager =
        IPoolManager(POOL_MANAGER_ADDRESS);

    // ───────────── User Parameters ─────────────
    address constant token0 = 
        0x4200000000000000000000000000000000000006; // WETH
    address constant token1 = 
        0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; // USDC
    uint24 constant fee = 499;
    int24 constant tickSpacing = 10;
    address constant hooks = address(0);

    uint160 constant startingSqrtPriceX96 = 
        79228162514264337593543950336; // 1:1 default


    // ───────────── Entry Points ─────────────
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

