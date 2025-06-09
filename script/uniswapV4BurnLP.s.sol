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
 * @title BurnLPPosition
 * @notice Script that burns a Uniswap V4 liquidity position and collects the underlying tokens
 */
contract BurnLPPosition is Script {
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
    IPermit2 public immutable permit2 = IPermit2(PERMIT2_ADDRESS);

    // ───────────── User Parameters ─────────────
    address token0 = 0x6C27BaE78f4763a7EF330baB2e63cFD94708DDa9; // MyToken
    address token1 = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; // USDC
    uint24 constant FEE_TIER = 500;
    int24 constant TICK_SPACING = 10;
    address constant HOOKS = address(0);

    // Position parameters (must match the position being burned)
    int24 constant TICK_LOWER = -225150;
    int24 constant TICK_UPPER = 0;
    uint128 constant LIQUIDITY_UNITS = 1_000;

    // The NFT token ID of the position to burn
    uint256 public positionId = 43696;

    // ───────────── Entry Points ─────────────
    function run() external {
        vm.startBroadcast();
        _run();
        vm.stopBroadcast();
    }

    function simulate() external {
        // Derive pool key and ID
        (, PoolId poolId) = _derivePoolKeyAndId();
        console.log("PoolId:");
        console.logBytes32(PoolId.unwrap(poolId));

        // Record starting balances
        uint256 startBalance0 = getTokenBalance(msg.sender, token0);
        uint256 startBalance1 = getTokenBalance(msg.sender, token1);
        console.log("Start Token0:", startBalance0);
        console.log("Start Token1:", startBalance1);

        // Impersonate and burn
        vm.startPrank(msg.sender);
        _burnPosition();
        vm.stopPrank();

        // Record ending balances and report received tokens
        uint256 endBalance0 = getTokenBalance(msg.sender, token0);
        uint256 endBalance1 = getTokenBalance(msg.sender, token1);
        console.log("End   Token0:", endBalance0);
        console.log("End   Token1:", endBalance1);
        console.log("Received Token0:", endBalance0 - startBalance0);
        console.log("Received Token1:", endBalance1 - startBalance1);
    }

    // ───────────── Main Flow ─────────────
    function _run() internal {
        // Derive pool key and ID
        (, PoolId poolId) = _derivePoolKeyAndId();
        console.log("PoolId:");
        console.logBytes32(PoolId.unwrap(poolId));

        // Record user's starting balances
        uint256 startBalance0 = getTokenBalance(msg.sender, token0);
        uint256 startBalance1 = getTokenBalance(msg.sender, token1);
        console.log("Start Token0:", startBalance0);
        console.log("Start Token1:", startBalance1);

        // Burn the LP position and collect tokens
        _burnPosition();

        // Record ending balances and report received tokens
        uint256 endBalance0 = getTokenBalance(msg.sender, token0);
        uint256 endBalance1 = getTokenBalance(msg.sender, token1);
        console.log("End   Token0:", endBalance0);
        console.log("End   Token1:", endBalance1);
        console.log("Received Token0:", endBalance0 - startBalance0);
        console.log("Received Token1:", endBalance1 - startBalance1);
    }

    /**
     * @notice Core burn logic: burns the position NFT and withdraws liquidity
     */
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

        console.log(
            "Current tick:",
            TickMath.getTickAtSqrtPrice(_getSqrtPrice(poolKey.toId()))
        );
        console.log("Burning position with ID:", positionId);
        console.log(" Lower tick:", TICK_LOWER);
        console.log(" Upper tick:", TICK_UPPER);

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

        // Execute the burn transaction - no approval needed
        positionManager.modifyLiquidities(abi.encode(actions, params), deadline);

        console.log("Liquidity position burned");
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
