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

// IMMUTABLE PARAMS
address constant arrakisNativeToken =
    0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
address constant uniswapNativeToken =
    0x0000000000000000000000000000000000000000;

contract SwapToSqrtPriceScriptETH is Script {
    using CurrencySettler for Currency;
    using StateLibrary for IPoolManager;
    using PoolIdLibrary for PoolKey;
    using TransientStateLibrary for IPoolManager;
    using BalanceDeltaLibrary for BalanceDelta;

    // USER DEFINED PARAMS
    address constant poolManagerAddress =
        0x000000000004444c5dc75cB358380D2e3dE08A90;
    address token0 = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599; // AAVE
    address token1 = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC
    address constant poolSwapTestAddress =
        0x1A8E953714B0eCB0eE7816F9A9c423FD7eB923AF;
    uint24 constant fee = 3000;
    int24 constant tickSpacing = 60;
    address constant hooks = address(0);

    uint160 constant desiredSqrtPriceX96 =
        2680113587184669498521649886995;

    // Addresses used in case of simulating a transfer of tokens to our wallet - some tokens are not plain ERC20 and we cannot mint
    address constant biggestToken0Holder =
        0x5Ee5bf7ae06D1Be5997A1A72006FE6C607eC6DE8; // staked aave contract
    address constant biggestToken1Holder =
        0x28C6c06298d514Db089934071355E5743bf21d60; // binance 14

    IPoolManager public immutable manager =
        IPoolManager(poolManagerAddress);

    function swap(
        PoolKey memory key,
        IPoolManager.SwapParams memory params,
        PoolSwapTest.TestSettings memory testSettings,
        bytes memory hookData
    ) public payable returns (BalanceDelta delta) {
        PoolSwapTest poolSwapTest =
            PoolSwapTest(poolSwapTestAddress);

        delta = poolSwapTest.swap(key, params, testSettings, hookData);

        console.log("Amount 0 : ");
        console.logInt(delta.amount0());
        console.log("Amount 1 : ");
        console.logInt(delta.amount1());
    }

    function run() external {
        // vm.startBroadcast();
        // _run();
        // vm.stopBroadcast();

        // in case you want to test the swap with large balances, uncomment below and comment the above
        simulate();
    }

    function simulate() internal {
        // Deal tokens to the sender
        // @dev Be VERY mindful of the decimals as they are not always 18
        dealTokens(msg.sender, token0, 100 * (10 ** 8)); // Deal 1000000 units of token0 (18 decimals)
        dealTokens(msg.sender, token1, 1_000_000 * (10 ** 6)); // Deal 1000000 units of token1 (6 decimals)

        console.log("Simulating swap...");
        console.log("Sender address:", msg.sender);
        console.log("ETH balance:", address(msg.sender).balance);
        console.log(
            "Token0 balance:", getTokenBalance(msg.sender, token0)
        );
        console.log(
            "Token1 balance:", getTokenBalance(msg.sender, token1)
        );

        // Run the swap
        vm.startPrank(msg.sender);
        _run();
        vm.stopPrank();
    }

    function dealTokens(
        address recipient,
        address token,
        uint256 amount
    ) internal {
        if (token == uniswapNativeToken) {
            // If the token is ETH, use `vm.deal` to set the ETH balance
            vm.deal(recipient, amount);
        } else {
            // If the token is non-native, transfer the tokens from the original holder (large amount)
            address originalHolder = token == token0
                ? biggestToken0Holder
                : biggestToken1Holder;
            bytes memory transferData = abi.encodeWithSignature(
                "transfer(address,uint256)", recipient, amount
            );
            vm.startPrank(originalHolder);
            (bool success, bytes memory data) =
                token.call(transferData);
            vm.stopPrank();
            require(
                success
                    && (data.length == 0 || abi.decode(data, (bool))),
                "Token transfer failed"
            );
        }
    }

    function getTokenBalance(
        address account,
        address token
    ) internal view returns (uint256) {
        if (token == uniswapNativeToken) {
            // If the token is ETH, return the ETH balance
            return account.balance;
        } else {
            // If the token is ERC20, return the token balance
            return IERC20Minimal(token).balanceOf(account);
        }
    }

    function _fetchBalances(
        Currency currency,
        address user,
        address deltaHolder
    )
        internal
        view
        returns (
            uint256 userBalance,
            uint256 poolBalance,
            int256 delta
        )
    {
        userBalance = currency.balanceOf(user);
        poolBalance = currency.balanceOf(address(manager));
        delta = manager.currencyDelta(deltaHolder, currency);
    }

    function _run() internal {
        Currency currency0;
        Currency currency1;

        // Determine currency0 and currency1 based on address order
        if (token0 == arrakisNativeToken) {
            token0 = uniswapNativeToken;
        }
        if (token1 == arrakisNativeToken) {
            token1 = uniswapNativeToken;
        }
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

        PoolId poolId = poolKey.toId();

        console.log("PoolId:");
        console.logBytes32(PoolId.unwrap(poolId));

        (uint160 sqrtPriceX96,,,) = manager.getSlot0(poolId);

        // Determine swap direction based on currency0 and token addresses
        bool zeroForOne = (sqrtPriceX96 > desiredSqrtPriceX96);
        console.log("zeroForOne:", zeroForOne);
        console.log("Current sqrtPriceX96 (before):", sqrtPriceX96);
        console.log("Desired sqrtPriceX96:", desiredSqrtPriceX96);

        // Store and log token balances before the swap
        uint256 token0BalanceBefore = token0 == uniswapNativeToken
            ? address(msg.sender).balance
            : IERC20Minimal(token0).balanceOf(address(msg.sender));
        uint256 token1BalanceBefore = token1 == uniswapNativeToken
            ? address(msg.sender).balance
            : IERC20Minimal(token1).balanceOf(address(msg.sender));
        console.log(
            "Token0 balance before swap:", token0BalanceBefore
        );
        console.log(
            "Token1 balance before swap:", token1BalanceBefore
        );

        // Prepare SwapParams with the desired sqrtPrice
        IPoolManager.SwapParams memory params = IPoolManager
            .SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: zeroForOne
                ? -int256(token0BalanceBefore)
                : -int256(token1BalanceBefore),
            sqrtPriceLimitX96: desiredSqrtPriceX96
        });
        // Prepare TestSettings
        PoolSwapTest.TestSettings memory testSettings = PoolSwapTest
            .TestSettings({takeClaims: false, settleUsingBurn: false});
        bytes memory hookData = "";
        // Approve PoolSwapTest contract to spend the tokens
        IERC20Minimal(token0).approve(
            address(poolSwapTestAddress), type(uint256).max
        );
        IERC20Minimal(token1).approve(
            address(poolSwapTestAddress), type(uint256).max
        );
        console.log("PoolKey details:");
        console.log(
            "Currency0:", address(Currency.unwrap(poolKey.currency0))
        );
        console.log(
            "Currency1:", address(Currency.unwrap(poolKey.currency1))
        );
        console.log("Fee:", poolKey.fee);
        console.log("TickSpacing:", poolKey.tickSpacing);
        console.log("Hooks:", address(poolKey.hooks));

        // Perform the swap
        swap(poolKey, params, testSettings, hookData);

        // Store and log token balances after the swap
        uint256 token0BalanceAfter = token0 == uniswapNativeToken
            ? address(msg.sender).balance
            : IERC20Minimal(token0).balanceOf(address(msg.sender));
        uint256 token1BalanceAfter = token1 == uniswapNativeToken
            ? address(msg.sender).balance
            : IERC20Minimal(token1).balanceOf(address(msg.sender));
        console.log("Token0 balance after swap:", token0BalanceAfter);
        console.log("Token1 balance after swap:", token1BalanceAfter);

        (uint160 sqrtPriceX96After,,,) = manager.getSlot0(poolId);
        console.log(
            "Current sqrtPriceX96 (after):", sqrtPriceX96After
        );

        console.log("Swap executed to reach desired sqrtPrice.");
    }
}
