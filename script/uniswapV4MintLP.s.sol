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

contract MintBetweenPrices is Script {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    // ───────────── Immutable Environment ─────────────
    address constant PERMIT2_ADDRESS =
        0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address constant POSITION_MANAGER =
        0xbD216513d74C8cf14cf4747E6AaA6420FF64ee9e;
    address constant POOL_MANAGER_ADDRESS =
        0x000000000004444c5dc75cB358380D2e3dE08A90;

    IPoolManager public immutable poolManager =
        IPoolManager(POOL_MANAGER_ADDRESS);
    IPositionManager public immutable positionMgr =
        IPositionManager(POSITION_MANAGER);
    IPermit2 public immutable permit2 = IPermit2(PERMIT2_ADDRESS);

    // ───────────── User Parameters ─────────────
    address public token0 = 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9; // AAVE
    address public token1 = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC
    uint24 constant FEE_TIER = 3000;
    int24 constant TICK_SPACING = 60;
    address constant HOOKS = address(0);

    uint160 constant DESIRED_SQRT_PRICE = 1023710556419588856013854;
    uint128 constant LIQUIDITY_UNITS = 1_000;
    uint128 constant MAX_AMOUNT0 = 0.01 ether;
    uint128 constant MAX_AMOUNT1 = 100 * 1e6; // USDC: 6 decimals

    // Holders for simulation
    address constant LARGE_HOLDER0 = 0x4da27a545c0c5B758a6BA100e3a049001de870f5;
    address constant LARGE_HOLDER1 = 0x28C6c06298d514Db089934071355E5743bf21d60;

    // ───────────── Entry Point ─────────────
    function run() external {
        simulate();
    }

    /// @notice Derive and sort token addresses, wrap as Currency, build PoolKey and PoolId
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

    function _run() internal {
        // 1) derive and log PoolId + current on‐chain state
        (, PoolId poolId) = _derivePoolKeyAndId();
        console.log("PoolId:");
        console.logBytes32(PoolId.unwrap(poolId));

        // 2) record user's starting balances
        uint256 startBalance0 = getTokenBalance(msg.sender, token0);
        uint256 startBalance1 = getTokenBalance(msg.sender, token1);
        console.log("Start Token0:", startBalance0);
        console.log("Start Token1:", startBalance1);

        // 3) mint the LP position
        _mintPosition(msg.sender);

        // 4) record ending balances and report consumption
        uint256 endBalance0 = getTokenBalance(msg.sender, token0);
        uint256 endBalance1 = getTokenBalance(msg.sender, token1);
        console.log("End   Token0:", endBalance0);
        console.log("End   Token1:", endBalance1);
        console.log("Minted Token0:", startBalance0 - endBalance0);
        console.log("Minted Token1:", startBalance1 - endBalance1);
    }

    function simulate() internal {
        // 1) fund caller
        dealTokens(msg.sender, token0, MAX_AMOUNT0);
        dealTokens(msg.sender, token1, MAX_AMOUNT1);

        // 2) derive and log PoolId + current on‐chain state
        (, PoolId poolId) = _derivePoolKeyAndId();
        console.log("PoolId:");
        console.logBytes32(PoolId.unwrap(poolId));

        // 3) record starting balances
        uint256 startBalance0 = getTokenBalance(msg.sender, token0);
        uint256 startBalance1 = getTokenBalance(msg.sender, token1);
        console.log("Start Token0:", startBalance0);
        console.log("Start Token1:", startBalance1);

        // 4) impersonate and mint
        vm.startPrank(msg.sender);
        _mintPosition(msg.sender);
        vm.stopPrank();

        // 5) record ending balances and report consumption
        uint256 endBalance0 = getTokenBalance(msg.sender, token0);
        uint256 endBalance1 = getTokenBalance(msg.sender, token1);
        console.log("End   Token0:", endBalance0);
        console.log("End   Token1:", endBalance1);
        console.log("Minted Token0:", startBalance0 - endBalance0);
        console.log("Minted Token1:", startBalance1 - endBalance1);
    }

    /// @notice Core mint logic: calculates ticks, builds calldata, approves via Permit2, and calls PositionManager
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

        _permit2Approve(token0);
        _permit2Approve(token1);

        uint256 deadline = block.timestamp + 2 minutes;
        uint256 ethValue = currency0.isAddressZero() ? MAX_AMOUNT0 : 0;

        positionMgr.modifyLiquidities{value: ethValue}(
            abi.encode(actions, params),
            deadline
        );

        console.log("Liquidity position minted");
    }

    // ───────────── Helper Functions ─────────────

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

        // approve Permit2 to transfer tokens on behalf of the user
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
