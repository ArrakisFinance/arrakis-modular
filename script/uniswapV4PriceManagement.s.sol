// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import "@uniswap/v4-core/src/types/PoolKey.sol";
import "@uniswap/v4-core/src/types/PoolId.sol";
import "@uniswap/v4-core/src/types/Currency.sol";
import "@uniswap/v4-core/src/libraries/TickMath.sol";
import "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import "@uniswap/v4-core/src/test/PoolSwapTest.sol";
import "@uniswap/v4-core/src/types/BalanceDelta.sol";
import "@uniswap/v4-core/src/libraries/TransientStateLibrary.sol";

import "@uniswap/v4-periphery/src/interfaces/IPositionManager.sol";
import "@uniswap/v4-periphery/src/libraries/Actions.sol";

import "@uniswap/v4-core/src/interfaces/external/IERC20Minimal.sol";
import "@uniswap/permit2/src/interfaces/IPermit2.sol";

contract UniswapV4PriceManagement is Script {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;
    using CurrencySettler for Currency;
    using TransientStateLibrary for IPoolManager;
    using BalanceDeltaLibrary for BalanceDelta;

    // ───────────── Immutable Environment ─────────────
    address constant PERMIT2_ADDRESS =
        0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address constant POSITION_MANAGER =
        0x7C5f5A4bBd8fD63184577525326123B519429bDc;
    address constant POOL_MANAGER_ADDRESS =
        0x498581fF718922c3f8e6A244956aF099B2652b2b;
    address constant POOL_SWAP_TEST_ADDRESS =
        0x1110F3650E5D7A0f47c23a4EaFa66C7A619115b8;

    // Native token representations
    address constant ARRAKIS_NATIVE_TOKEN =
        0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address constant UNISWAP_NATIVE_TOKEN =
        0x0000000000000000000000000000000000000000;

    IPoolManager public immutable poolManager =
        IPoolManager(POOL_MANAGER_ADDRESS);
    IPositionManager public immutable positionManager =
        IPositionManager(POSITION_MANAGER);
    IPermit2 public immutable permit2 = IPermit2(PERMIT2_ADDRESS);

    // ───────────── User Parameters ─────────────
    address token0 = 0x6C27BaE78f4763a7EF330baB2e63cFD94708DDa9; // MyToken
    address token1 = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; // USDC
    uint24 constant FEE_TIER = 500;
    int24 constant TICK_SPACING = 10;
    address constant HOOKS = address(0);

    // Position parameters
    uint160 constant DESIRED_SQRT_PRICE = 1123710556419588856013850;
    uint128 constant LIQUIDITY_UNITS = 1_000;
    uint128 constant MAX_AMOUNT0 = 20 ether;
    uint128 constant MAX_AMOUNT1 = 10 * 1e6; // USDC: 6 decimals

    // Swap parameters
    uint160 constant TARGET_SQRT_PRICE = 1123710556419588856013850; // Target price after swap

    // Position ID storage (set during mint operation)
    uint256 public positionId;

    // Holders for simulation
    address constant LARGE_HOLDER0 = 0xb836043d800BE77944637a0e3e610C7a657dF75A;
    address constant LARGE_HOLDER1 = 0xb836043d800BE77944637a0e3e610C7a657dF75A;

    // ───────────── Entry Points ─────────────
    function run() external {
        vm.startBroadcast();
        _run();
        vm.stopBroadcast();

        // _simulate();
    }

    function _simulate() internal {
        // Fund sender wallet
        dealTokens(msg.sender, token0, MAX_AMOUNT0);
        dealTokens(msg.sender, token1, MAX_AMOUNT1);

        console.log("\n=== SIMULATION START ===");
        console.log("Sender:", msg.sender);
        console.log("Initial balances:");
        console.log(" Token0:", getTokenBalance(msg.sender, token0));
        console.log(" Token1:", getTokenBalance(msg.sender, token1));

        // Execute the entire flow with impersonation
        vm.startPrank(msg.sender);
        _run();
        vm.stopPrank();

        console.log("\n=== SIMULATION COMPLETE ===");
        console.log("Final balances:");
        console.log(" Token0:", getTokenBalance(msg.sender, token0));
        console.log(" Token1:", getTokenBalance(msg.sender, token1));
    }

    // ───────────── Main Flow ─────────────
    function _run() internal {
        (PoolKey memory poolKey, PoolId poolId) = _derivePoolKeyAndId();
        console.log("\n=== POOL DETAILS ===");
        console.log("PoolId:");
        console.logBytes32(PoolId.unwrap(poolId));

        // Record starting balances
        uint256 startBalance0 = getTokenBalance(msg.sender, token0);
        uint256 startBalance1 = getTokenBalance(msg.sender, token1);
        console.log("Starting balances:");
        console.log(" Token0:", startBalance0);
        console.log(" Token1:", startBalance1);

        // MINT LP POSITION
        console.log("\n=== STEP 1: MINTING LP POSITION ===");
        positionId = _mintPosition(msg.sender);
        console.log("Minted position ID:", positionId);

        uint256 postMintBalance0 = getTokenBalance(msg.sender, token0);
        uint256 postMintBalance1 = getTokenBalance(msg.sender, token1);
        console.log("Post-mint balances:");
        console.log(" Token0:", postMintBalance0);
        console.log(" Token1:", postMintBalance1);

        // EXECUTE SWAP TO TARGET PRICE
        console.log("\n=== STEP 2: EXECUTING SWAP ===");
        _executeSwap(poolKey);

        uint256 postSwapBalance0 = getTokenBalance(msg.sender, token0);
        uint256 postSwapBalance1 = getTokenBalance(msg.sender, token1);
        console.log("Post-swap balances:");
        console.log(" Token0:", postSwapBalance0);
        console.log(" Token1:", postSwapBalance1);

        // BURN LP POSITION
        console.log("\n=== STEP 3: BURNING LP POSITION ===");
        _burnPosition();

        uint256 finalBalance0 = getTokenBalance(msg.sender, token0);
        uint256 finalBalance1 = getTokenBalance(msg.sender, token1);
        console.log("Final balances:");
        console.log(" Token0:", finalBalance0);
        console.log(" Token1:", finalBalance1);

        console.log("\n=== SUMMARY ===");

        uint256 change0 = finalBalance0 >= startBalance0
            ? finalBalance0 - startBalance0
            : startBalance0 - finalBalance0;
        uint256 change1 = finalBalance1 >= startBalance1
            ? finalBalance1 - startBalance1
            : startBalance1 - finalBalance1;

        console.log("Total changes:");
        console.log(
            " Token0:",
            finalBalance0 > startBalance0 ? "+" : "",
            change0
        );
        console.log(
            " Token1:",
            finalBalance1 > startBalance1 ? "+" : "",
            change1
        );
    }

    // ───────────── Step 1: Mint LP Position ─────────────
    function _mintPosition(address recipient) internal returns (uint256) {
        // Order token addresses lexicographically
        if (token0 > token1) {
            (token0, token1) = (token1, token0);
        }

        Currency currency0 = Currency.wrap(token0);
        Currency currency1 = Currency.wrap(token1);

        PoolKey memory poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: FEE_TIER,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(HOOKS)
        });

        uint160 currentSqrtPrice = _getSqrtPrice(poolKey.toId());
        (int24 tickLower, int24 tickUpper) = _computeTickRange(
            currentSqrtPrice,
            DESIRED_SQRT_PRICE
        );

        int24 currentTick = TickMath.getTickAtSqrtPrice(currentSqrtPrice);

        console.log("Current tick:", currentTick);
        console.log("Minting between ticks:");
        console.log(" Lower tick:", tickLower);
        console.log(" Upper tick:", tickUpper);

        (bytes memory actions, bytes[] memory params) = _buildModifyArguments(
            poolKey,
            tickLower,
            tickUpper,
            recipient,
            currency0,
            currency1
        );

        // Setup approvals for tokens via Permit2
        _permit2Approve(token0);
        _permit2Approve(token1);

        uint256 deadline = block.timestamp + 2 minutes;
        uint256 ethValue = currency0.isAddressZero() ? MAX_AMOUNT0 : 0;

        // Get the ID that will be assigned to our position
        uint256 tokenId = positionManager.nextTokenId();

        // Mint the position
        positionManager.modifyLiquidities{value: ethValue}(
            abi.encode(actions, params),
            deadline
        );

        console.log("Liquidity position minted");
        return tokenId;
    }

    // ───────────── Step 2: Execute Swap ─────────────
    function _executeSwap(PoolKey memory poolKey) internal {
        // Get current price and log price details
        (uint160 currentSqrtPrice, int24 currentTick, , ) = poolManager
            .getSlot0(poolKey.toId());
        console.log("Current sqrtPriceX96:", currentSqrtPrice);
        console.log("Current tick:", currentTick);
        console.log("Target sqrtPriceX96:", TARGET_SQRT_PRICE);

        // Determine swap direction based on price comparison
        bool zeroForOne = (currentSqrtPrice > TARGET_SQRT_PRICE);
        console.log("Swap direction (zeroForOne):", zeroForOne);

        // Determine token to swap
        address tokenIn = zeroForOne ? token0 : token1;
        uint256 maxAmount = zeroForOne ? MAX_AMOUNT0 / 10 : MAX_AMOUNT1 / 10; // Use 10% of max amount

        console.log("Token to swap:", tokenIn);
        console.log("Max swap amount:", maxAmount);

        // Approve tokens for PoolSwapTest
        IERC20Minimal(tokenIn).approve(
            POOL_SWAP_TEST_ADDRESS,
            type(uint256).max
        );

        // Construct swap parameters
        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: -int256(maxAmount), // Exact price target, not exact amount
            sqrtPriceLimitX96: TARGET_SQRT_PRICE
        });

        PoolSwapTest.TestSettings memory testSettings = PoolSwapTest
            .TestSettings({takeClaims: false, settleUsingBurn: false});

        // Execute the swap
        PoolSwapTest poolSwapTest = PoolSwapTest(POOL_SWAP_TEST_ADDRESS);
        BalanceDelta delta = poolSwapTest.swap(
            poolKey,
            params,
            testSettings,
            abi.encode(msg.sender) // Hook data
        );

        console.log("Swap executed:");
        console.log(
            " Amount0 delta:",
            uint256(
                delta.amount0() > 0
                    ? int256(delta.amount0())
                    : -int256(delta.amount0())
            )
        );
        console.log(
            " Amount1 delta:",
            uint256(
                delta.amount1() > 0
                    ? int256(delta.amount1())
                    : -int256(delta.amount1())
            )
        );

        // Check new price
        (uint160 newSqrtPrice, int24 newTick, , ) = poolManager.getSlot0(
            poolKey.toId()
        );
        console.log("New sqrtPriceX96:", newSqrtPrice);
        console.log("New tick:", newTick);
    }

    // ───────────── Step 3: Burn LP Position ─────────────
    function _burnPosition() internal {
        // Order token addresses lexicographically
        if (token0 > token1) {
            (token0, token1) = (token1, token0);
        }

        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: FEE_TIER,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(HOOKS)
        });

        (uint160 currentSqrtPrice, , , ) = poolManager.getSlot0(poolKey.toId());
        int24 currentTick = TickMath.getTickAtSqrtPrice(currentSqrtPrice);
        console.log("Current tick:", currentTick);
        console.log("Burning position with ID:", positionId);

        // Encode BURN_POSITION action with TAKE_PAIR for token collection
        bytes memory actions = abi.encodePacked(
            uint8(Actions.BURN_POSITION),
            uint8(Actions.TAKE_PAIR)
        );

        // Encode burn parameters
        bytes[] memory params = new bytes[](2);
        params[0] = abi.encode(
            positionId, // tokenId
            uint128(0), // amount0Min - no slippage protection
            uint128(0), // amount1Min - no slippage protection
            bytes("") // hookData
        );
        params[1] = abi.encode( // TAKE_PAIR needs the recipient
            Currency.wrap(token0),
            Currency.wrap(token1),
            msg.sender // Who receives the tokens
        );

        uint256 deadline = block.timestamp + 2 minutes;

        // Execute the burn transaction
        positionManager.modifyLiquidities(
            abi.encode(actions, params),
            deadline
        );

        console.log("Liquidity position burned");
    }

    // ───────────── Helper Functions ─────────────
    function _derivePoolKeyAndId()
        internal
        view
        returns (PoolKey memory poolKey, PoolId poolId)
    {
        address t0 = token0;
        address t1 = token1;
        if (t0 > t1) (t0, t1) = (t1, t0);

        Currency c0 = Currency.wrap(t0);
        Currency c1 = Currency.wrap(t1);

        poolKey = PoolKey({
            currency0: c0,
            currency1: c1,
            fee: FEE_TIER,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(HOOKS)
        });
        poolId = poolKey.toId();
    }

    function _getSqrtPrice(PoolId poolId) internal view returns (uint160) {
        (uint160 price, , , ) = poolManager.getSlot0(poolId);
        return price;
    }

    function _computeTickRange(
        uint160 currentPrice,
        uint160 targetPrice
    ) internal pure returns (int24 lower, int24 upper) {
        int24 currentTick = TickMath.getTickAtSqrtPrice(currentPrice);
        int24 targetTick = TickMath.getTickAtSqrtPrice(targetPrice);

        lower = _roundToSpacing(
            currentTick < targetTick ? currentTick : targetTick
        );
        upper = _roundToSpacing(
            currentTick < targetTick ? targetTick : currentTick
        );

        if (upper - lower < TICK_SPACING) {
            upper = lower + TICK_SPACING;
        }
    }

    function _roundToSpacing(int24 tick) internal pure returns (int24) {
        int24 aligned = (tick / TICK_SPACING) * TICK_SPACING;
        if (tick < 0 && tick % TICK_SPACING != 0) {
            aligned -= TICK_SPACING;
        }
        return aligned;
    }

    function _buildModifyArguments(
        PoolKey memory key,
        int24 lower,
        int24 upper,
        address recipient,
        Currency currency0,
        Currency currency1
    ) internal pure returns (bytes memory actions, bytes[] memory params) {
        actions = abi.encodePacked(
            uint8(Actions.MINT_POSITION),
            uint8(Actions.SETTLE_PAIR)
        );

        params = new bytes[](2);
        params[0] = abi.encode(
            key,
            lower,
            upper,
            LIQUIDITY_UNITS,
            MAX_AMOUNT0,
            MAX_AMOUNT1,
            recipient,
            bytes("") // hook data
        );
        params[1] = abi.encode(currency0, currency1);
    }

    function _permit2Approve(address token) internal {
        if (token == address(0)) {
            return;
        }

        // Approve Permit2 to transfer tokens on behalf of the user
        IERC20Minimal(token).approve(PERMIT2_ADDRESS, type(uint256).max);

        permit2.approve(
            token,
            POSITION_MANAGER,
            type(uint160).max,
            uint48(block.timestamp + 365 days)
        );
    }

    function dealTokens(address to, address token, uint256 amount) internal {
        if (token == address(0)) {
            vm.deal(to, amount);
        } else {
            address source = (token == token0) ? LARGE_HOLDER0 : LARGE_HOLDER1;
            vm.prank(source);
            IERC20Minimal(token).transfer(to, amount);
        }
    }

    function getTokenBalance(
        address who,
        address token
    ) internal view returns (uint256) {
        if (token == address(0)) {
            return who.balance;
        }
        return IERC20Minimal(token).balanceOf(who);
    }
}
