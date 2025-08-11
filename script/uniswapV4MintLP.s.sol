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

import "@uniswap/v4-periphery/src/interfaces/IPositionManager.sol";
import "@uniswap/v4-periphery/src/libraries/Actions.sol";

import "@uniswap/v4-core/src/interfaces/external/IERC20Minimal.sol";
import "@uniswap/permit2/src/interfaces/IPermit2.sol";

/**
 * @title MintBetweenPrices
 * @notice Script that mints a Uniswap V4 liquidity position between specified price ranges
 */
contract MintBetweenPrices is Script {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    // ───────────── Immutable Environment ─────────────
    address constant PERMIT2_ADDRESS =
        0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address constant POSITION_MANAGER =
        0x7C5f5A4bBd8fD63184577525326123B519429bDc;
    address constant POOL_MANAGER_ADDRESS =
        0x498581fF718922c3f8e6A244956aF099B2652b2b;

    IPoolManager public immutable poolManager =
        IPoolManager(POOL_MANAGER_ADDRESS);
    IPositionManager public immutable positionManager =
        IPositionManager(POSITION_MANAGER);
    IMulticall_v4 public immutable positionManagerMulticall =
        IMulticall_v4(POSITION_MANAGER);
    IPermit2 public immutable permit2 = IPermit2(PERMIT2_ADDRESS);

    // ───────────── User Parameters ─────────────
    address token0 = 0x6C27BaE78f4763a7EF330baB2e63cFD94708DDa9; // MyToken
    address token1 = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; // USDC
    uint24 constant FEE_TIER = 500;
    int24 constant TICK_SPACING = 10;
    address constant HOOKS = address(0);

    uint160 constant TARGET_SQRT_PRICE = 1123710556419588856013850;
    uint128 constant LIQUIDITY_UNITS = 1_000;
    uint128 constant MAX_AMOUNT0 = 20 ether;
    uint128 constant MAX_AMOUNT1 = 10 * 1e6; // USDC: 6 decimals

    // Holders for simulation
    address constant LARGE_HOLDER0 = 0xb836043d800BE77944637a0e3e610C7a657dF75A;
    address constant LARGE_HOLDER1 = 0xb836043d800BE77944637a0e3e610C7a657dF75A;

    // ───────────── Entry Points ─────────────
    function run() external {
        vm.startBroadcast();
        _run();
        vm.stopBroadcast();
    }

    function simulate() external {
        // Fund caller
        dealTokens(msg.sender, token0, MAX_AMOUNT0);
        dealTokens(msg.sender, token1, MAX_AMOUNT1);

        // Derive and log pool information
        (, PoolId poolId) = _derivePoolKeyAndId();
        console.log("PoolId:");
        console.logBytes32(PoolId.unwrap(poolId));

        // Record starting balances
        uint256 startBalance0 = getTokenBalance(msg.sender, token0);
        uint256 startBalance1 = getTokenBalance(msg.sender, token1);
        console.log("Start Token0:", startBalance0);
        console.log("Start Token1:", startBalance1);

        // Impersonate and mint
        vm.startPrank(msg.sender);
        _mintPosition(msg.sender);
        vm.stopPrank();

        // Record ending balances and report consumption
        uint256 endBalance0 = getTokenBalance(msg.sender, token0);
        uint256 endBalance1 = getTokenBalance(msg.sender, token1);
        console.log("End   Token0:", endBalance0);
        console.log("End   Token1:", endBalance1);
        console.log("Minted Token0:", startBalance0 - endBalance0);
        console.log("Minted Token1:", startBalance1 - endBalance1);
    }

    // ───────────── Core Logic ─────────────
    function _run() internal {
        // Derive and log pool information
        (, PoolId poolId) = _derivePoolKeyAndId();
        console.log("PoolId:");
        console.logBytes32(PoolId.unwrap(poolId));

        // Record starting balances
        uint256 startBalance0 = getTokenBalance(msg.sender, token0);
        uint256 startBalance1 = getTokenBalance(msg.sender, token1);
        console.log("Start Token0:", startBalance0);
        console.log("Start Token1:", startBalance1);

        // Mint the LP position
        _mintPosition(msg.sender);

        // Record ending balances and report consumption
        uint256 endBalance0 = getTokenBalance(msg.sender, token0);
        uint256 endBalance1 = getTokenBalance(msg.sender, token1);
        console.log("End   Token0:", endBalance0);
        console.log("End   Token1:", endBalance1);
        console.log("Minted Token0:", startBalance0 - endBalance0);
        console.log("Minted Token1:", startBalance1 - endBalance1);
    }

    /**
     * @notice Core mint logic: calculates ticks, builds calldata, approves via Permit2, and calls PositionManager
     * @param recipient Address that will receive the minted liquidity position
     */
    function _mintPosition(address recipient) internal {
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
            TARGET_SQRT_PRICE
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

        _permit2Approve(token0);
        _permit2Approve(token1);

        uint256 deadline = block.timestamp + 2 minutes;
        uint256 ethValue = currency0.isAddressZero() ? MAX_AMOUNT0 : 0;

        // Do both operations in a multicall because forge Script execution is not atomic.
        bytes[] memory queryIdAndMintLiquidityCalls = new bytes[](2);

        queryIdAndMintLiquidityCalls[0] = abi.encodeWithSelector(
            positionManager.nextTokenId.selector
        );

        queryIdAndMintLiquidityCalls[1] = abi.encodeWithSelector(
            positionManager.modifyLiquidities.selector,
            abi.encode(actions, params),
            deadline
        );

        bytes[] memory callsResults = positionManagerMulticall
            .multicall{value: ethValue}(queryIdAndMintLiquidityCalls);

        uint256 positionId = abi.decode(callsResults[0], (uint256));

        console.log("Liquidity position minted with id:", positionId);
    }

    // ───────────── Helper Functions ─────────────
    /**
     * @notice Derive and sort token addresses, wrap as Currency, build PoolKey and PoolId
     * @return poolKey The constructed pool key
     * @return poolId The derived pool ID
     */
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

    /**
     * @notice Get sqrt price for a pool
     * @param poolId ID of the pool to query
     * @return Current sqrt price X96 of the pool
     */
    function _getSqrtPrice(PoolId poolId) internal view returns (uint160) {
        (uint160 price, , , ) = poolManager.getSlot0(poolId);
        return price;
    }

    /**
     * @notice Compute tick range for position based on current and target prices
     * @param currentPrice Current sqrt price of the pool
     * @param targetPrice Target sqrt price for positioning
     * @return lower Lower tick boundary (aligned to tick spacing)
     * @return upper Upper tick boundary (aligned to tick spacing)
     */
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

    /**
     * @notice Rounds a tick to the nearest tick spacing
     * @param tick Tick value to round
     * @return Rounded tick aligned to tick spacing
     */
    function _roundToSpacing(int24 tick) internal pure returns (int24) {
        int24 aligned = (tick / TICK_SPACING) * TICK_SPACING;
        if (tick < 0 && tick % TICK_SPACING != 0) {
            aligned -= TICK_SPACING;
        }
        return aligned;
    }

    /**
     * @notice Build arguments for the modifyLiquidities call
     * @param key Pool key
     * @param lower Lower tick bound
     * @param upper Upper tick bound
     * @param recipient Address to receive the position
     * @param currency0 Token0 as Currency
     * @param currency1 Token1 as Currency
     * @return actions Encoded actions to perform
     * @return params Parameters for the actions
     */
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

    /**
     * @notice Set up approvals for token transfer through Permit2
     * @param token Address of token to approve
     */
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

    /**
     * @notice Transfer tokens to an address for simulation
     * @param to Recipient address
     * @param token Token address (address(0) for native ETH)
     * @param amount Amount to transfer
     */
    function dealTokens(address to, address token, uint256 amount) internal {
        if (token == address(0)) {
            vm.deal(to, amount);
        } else {
            address source = (token == token0) ? LARGE_HOLDER0 : LARGE_HOLDER1;
            vm.prank(source);
            IERC20Minimal(token).transfer(to, amount);
        }
    }

    /**
     * @notice Get token balance for an account
     * @param who Address to check balance for
     * @param token Token address (address(0) for native ETH)
     * @return Token balance
     */
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
