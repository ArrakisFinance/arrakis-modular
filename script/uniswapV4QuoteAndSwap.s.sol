// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import "@uniswap/v4-core/src/test/PoolSwapTest.sol";
import "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import "@uniswap/v4-core/src/types/PoolKey.sol";
import "@uniswap/v4-core/src/interfaces/external/IERC20Minimal.sol";
import "@uniswap/v4-core/src/types/BalanceDelta.sol";
import "@uniswap/v4-core/src/types/Currency.sol";
import "@uniswap/v4-core/src/types/PoolId.sol";
import "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import "@uniswap/v4-core/src/libraries/TransientStateLibrary.sol";

// Protocol constants
address constant arrakisNativeToken = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
address constant uniswapNativeToken = 0x0000000000000000000000000000000000000000;

/**
 * @title SwapToSqrtPriceScriptETH
 * @notice Script that performs a swap in a Uniswap V4 pool to reach a specific sqrt price
 */
contract SwapToSqrtPriceScriptETH is Script {
    using CurrencySettler for Currency;
    using StateLibrary for IPoolManager;
    using PoolIdLibrary for PoolKey;
    using TransientStateLibrary for IPoolManager;
    using BalanceDeltaLibrary for BalanceDelta;

    // Configuration parameters
    address constant poolManagerAddress =
        0x498581fF718922c3f8e6A244956aF099B2652b2b;
    address token0 = 0x6C27BaE78f4763a7EF330baB2e63cFD94708DDa9; // MyToken
    address token1 = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; // USDC
    address constant poolSwapTestAddress =
        0x1110F3650E5D7A0f47c23a4EaFa66C7A619115b8;
    uint24 constant fee = 500;
    int24 constant tickSpacing = 10;
    address constant hooks = address(0);

    // Target price for the swap
    uint160 constant desiredSqrtPriceX96 = 1123710556419588856013850;

    // Token holder addresses for simulation
    address constant biggestToken0Holder =
        0x4da27a545c0c5B758a6BA100e3a049001de870f5;
    address constant biggestToken1Holder =
        0x28C6c06298d514Db089934071355E5743bf21d60;

    IPoolManager public immutable manager = IPoolManager(poolManagerAddress);

    /**
     * @notice Execute a swap through the PoolSwapTest contract
     * @param key The pool key
     * @param params The swap parameters
     * @param testSettings Test settings for the swap
     * @param hookData Hook data to pass to the swap
     * @return delta The balance delta resulting from the swap
     */
    function swap(
        PoolKey memory key,
        IPoolManager.SwapParams memory params,
        PoolSwapTest.TestSettings memory testSettings,
        bytes memory hookData
    ) public payable returns (BalanceDelta delta) {
        PoolSwapTest poolSwapTest = PoolSwapTest(poolSwapTestAddress);

        delta = poolSwapTest.swap(key, params, testSettings, hookData);

        console.log("Amount 0 : ");
        console.logInt(delta.amount0());
        console.log("Amount 1 : ");
        console.logInt(delta.amount1());
    }

    /**
     * @notice Script entry point
     */
    function run() external {
        vm.startBroadcast();
        _run();
        vm.stopBroadcast();
    }

    /**
     * @notice Simulation mode with token balances
     */
    function simulate() internal {
        // Deal tokens to the sender with appropriate decimals
        dealTokens(msg.sender, token0, 100 * (10 ** 18));
        dealTokens(msg.sender, token1, 1_000_000 * (10 ** 6));

        console.log("Simulating swap...");
        console.log("Sender address:", msg.sender);
        console.log("ETH balance:", address(msg.sender).balance);
        console.log("Token0 balance:", getTokenBalance(msg.sender, token0));
        console.log("Token1 balance:", getTokenBalance(msg.sender, token1));

        vm.startPrank(msg.sender);
        _run();
        vm.stopPrank();
    }

    /**
     * @notice Provide tokens to an address for simulation purposes
     * @param recipient Address to receive tokens
     * @param token Token address (or zero for native ETH)
     * @param amount Amount of tokens to provide
     */
    function dealTokens(
        address recipient,
        address token,
        uint256 amount
    ) internal {
        if (token == uniswapNativeToken) {
            vm.deal(recipient, amount);
        } else {
            address originalHolder = token == token0
                ? biggestToken0Holder
                : biggestToken1Holder;
            bytes memory transferData = abi.encodeWithSignature(
                "transfer(address,uint256)",
                recipient,
                amount
            );
            vm.startPrank(originalHolder);
            (bool success, bytes memory data) = token.call(transferData);
            vm.stopPrank();
            require(
                success && (data.length == 0 || abi.decode(data, (bool))),
                "Token transfer failed"
            );
        }
    }

    /**
     * @notice Get token balance for an account
     * @param account Address to check balance for
     * @param token Token address (or zero for native ETH)
     * @return Token balance
     */
    function getTokenBalance(
        address account,
        address token
    ) internal view returns (uint256) {
        if (token == uniswapNativeToken) {
            return account.balance;
        } else {
            return IERC20Minimal(token).balanceOf(account);
        }
    }

    /**
     * @notice Core execution logic
     */
    function _run() internal {
        Currency currency0;
        Currency currency1;

        // Handle native token representation and sort currencies
        if (token0 == arrakisNativeToken) token0 = uniswapNativeToken;
        if (token1 == arrakisNativeToken) token1 = uniswapNativeToken;

        if (uint160(token0) < uint160(token1)) {
            currency0 = Currency.wrap(token0);
            currency1 = Currency.wrap(token1);
        } else {
            currency0 = Currency.wrap(token1);
            currency1 = Currency.wrap(token0);
        }

        // Configure pool key
        PoolKey memory poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: fee,
            tickSpacing: tickSpacing,
            hooks: IHooks(hooks)
        });

        PoolId poolId = poolKey.toId();

        console.log("PoolId:");
        console.logBytes32(PoolId.unwrap(poolId));

        // Get current price and determine swap direction
        (uint160 sqrtPriceX96, , , ) = manager.getSlot0(poolId);
        bool zeroForOne = (sqrtPriceX96 > desiredSqrtPriceX96);

        console.log("zeroForOne:", zeroForOne);
        console.log("Current sqrtPriceX96 (before):", sqrtPriceX96);
        console.log("Desired sqrtPriceX96:", desiredSqrtPriceX96);

        // Record pre-swap balances
        uint256 token0BalanceBefore = token0 == uniswapNativeToken
            ? address(msg.sender).balance
            : IERC20Minimal(token0).balanceOf(address(msg.sender));
        uint256 token1BalanceBefore = token1 == uniswapNativeToken
            ? address(msg.sender).balance
            : IERC20Minimal(token1).balanceOf(address(msg.sender));

        console.log("Token0 balance before swap:", token0BalanceBefore);
        console.log("Token1 balance before swap:", token1BalanceBefore);

        // Configure swap parameters
        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: zeroForOne
                ? -int256(token0BalanceBefore)
                : -int256(token1BalanceBefore),
            sqrtPriceLimitX96: desiredSqrtPriceX96
        });

        PoolSwapTest.TestSettings memory testSettings = PoolSwapTest
            .TestSettings({takeClaims: false, settleUsingBurn: false});

        bytes memory hookData = "";

        // Set approvals for the swap
        IERC20Minimal(token0).approve(
            address(poolSwapTestAddress),
            type(uint256).max
        );
        IERC20Minimal(token1).approve(
            address(poolSwapTestAddress),
            type(uint256).max
        );

        // Log pool configuration
        console.log("PoolKey details:");
        console.log("Currency0:", address(Currency.unwrap(poolKey.currency0)));
        console.log("Currency1:", address(Currency.unwrap(poolKey.currency1)));
        console.log("Fee:", poolKey.fee);
        console.log("TickSpacing:", poolKey.tickSpacing);
        console.log("Hooks:", address(poolKey.hooks));

        // Execute swap
        swap(poolKey, params, testSettings, hookData);

        // Record and report post-swap balances
        uint256 token0BalanceAfter = token0 == uniswapNativeToken
            ? address(msg.sender).balance
            : IERC20Minimal(token0).balanceOf(address(msg.sender));
        uint256 token1BalanceAfter = token1 == uniswapNativeToken
            ? address(msg.sender).balance
            : IERC20Minimal(token1).balanceOf(address(msg.sender));

        console.log("Token0 balance after swap:", token0BalanceAfter);
        console.log("Token1 balance after swap:", token1BalanceAfter);

        // Verify target price was reached
        (uint160 sqrtPriceX96After, , , ) = manager.getSlot0(poolId);
        console.log("Current sqrtPriceX96 (after):", sqrtPriceX96After);
        console.log("Swap executed to reach desired sqrtPrice.");
    }
}
