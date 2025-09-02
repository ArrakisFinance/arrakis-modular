// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";
import "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import "@uniswap/v4-core/src/interfaces/external/IERC20Minimal.sol";
import {IUniswapV3Factory} from
    "../src/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "../src/interfaces/IUniswapV3Pool.sol";
import {INonfungiblePositionManager} from
    "../src/interfaces/INonfungiblePositionManager.sol";
import {IAerodromeSwapRouter} from "../src/interfaces/IAerodromeSwapRouter.sol";
import {LiquidityAmounts} from
    "@v3-lib-0.8/contracts/LiquidityAmounts.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";

/**
 * @title AerodromePriceMove
 * @notice Script that performs a price move on Aerodrome DEX
 */
contract AerodromePriceMove is Script {
    // Configuration parameters
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant SWAP_ROUTER_ADDRESS = 0xBE6D8f0d05cC4be24d5167a3eF062215bE6D18a5;
    address constant FACTORY_ADDRESS = 0x5e7BB104d84c7CB9B682AaC2F3d509f5F406809A;
    address constant NFT_POSITION_MANAGER_ADDRESS = 0x827922686190790b37229fd06084350E74485b72;

    // Pool configuration parameters
    address constant TOKEN0 = WETH;
    address constant TOKEN1 = 0xB0fFa8000886e57F86dd5264b9582b2Ad87b2b91;
    int24 constant TICK_SPACING = 200;

    // Mint parameters
    uint128 constant LIQUIDITY = 2;
    
    // Swap parameters
    uint160 constant SQRT_PRICE_TARGET_X96 = 18572096475904342638375800406016;
    uint256 constant amountIn = 32; // To adjust after simulation

    // Token holder addresses for simulation
    address constant whaleToken0Holder =
        0x621e7c767004266c8109e83143ab0Da521B650d6;
    address constant whaleToken1Holder =
        0x198138E69A79B40518BAc88B537aF8b030Ec9F83;

    // Aerodrome contracts
    IAerodromeSwapRouter public immutable swapRouter = IAerodromeSwapRouter(SWAP_ROUTER_ADDRESS);
    IUniswapV3Factory public immutable factory = IUniswapV3Factory(FACTORY_ADDRESS);
    IUniswapV3Pool pool = IUniswapV3Pool(
            factory.getPool(
                TOKEN0, TOKEN1, TICK_SPACING
            )
        );
    INonfungiblePositionManager public immutable nftPositionManager = INonfungiblePositionManager(NFT_POSITION_MANAGER_ADDRESS);

    /**
     * @notice Script entry point
     */
    function run() external {
        //_simulate(); // Uncomment this and comment out the lines below to simulate the script
        vm.startBroadcast();
        _run();
        vm.stopBroadcast();
    }

    /**
     * @notice Simulation mode with token balances
     */
    function _simulate() internal {

        console.log("Simulating Aerodrome price change...");
        // Deal tokens to the sender - ensure enough for the swap
        _dealTokens(msg.sender, TOKEN0, 1 * (10 ** 18)); // 1 WETH
        _dealTokens(msg.sender, TOKEN1, 1_000_000 * (10 ** 18)); // 1M of token1

        vm.startPrank(msg.sender);
        _run();
        vm.stopPrank();
    }

    /**
     * @notice Core execution logic - implements Aerodrome mint + swap + burn
     */
    function _run() internal {
        _checkParameters();

        console.log("\nStarting Aerodrome price change execution...");
        (uint160 sqrtPriceX96Before, int24 tickBefore,,,,) = pool.slot0();

        address tokenIn = sqrtPriceX96Before < SQRT_PRICE_TARGET_X96 ? TOKEN1 : TOKEN0;
        address tokenOut = sqrtPriceX96Before < SQRT_PRICE_TARGET_X96 ? TOKEN0 : TOKEN1;

        console.log("Token In:", tokenIn);
        console.log("Token Out:", tokenOut);

        // Mint position
        (uint256 tokenId, uint128 liquidity) = _mintPosition();
        
        console.log("\nRecord pre-swap values...");
        // Record pre-swap balance
        uint256 tokenInBalanceBefore = _getTokenBalance(address(msg.sender), tokenIn);
        uint256 tokenOutBalanceBefore = _getTokenBalance(address(msg.sender), tokenOut);

        console.log("Token In balance before swap:", tokenInBalanceBefore);
        console.log("Token Out balance before swap:", tokenOutBalanceBefore);

        console.log("Sqrt Price X96 before swap:", sqrtPriceX96Before);
        console.log("Tick before swap:", tickBefore);

        // Ensure we have enough balance for the swap
        require(tokenInBalanceBefore >= amountIn, "Insufficient token balance for swap");

        // Configure swap parameters (matching TypeScript script)
        IAerodromeSwapRouter.ExactInputSingleParams memory params = IAerodromeSwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            tickSpacing: TICK_SPACING,
            recipient: msg.sender,
            deadline: block.timestamp + 30, // 30 seconds deadline
            amountIn: amountIn,
            amountOutMinimum: 0, // No minimum
            sqrtPriceLimitX96: SQRT_PRICE_TARGET_X96
        });

        console.log("\nApproving router for token spend...");
        // Approve the swap router to spend tokens
        IERC20Minimal(tokenIn).approve(SWAP_ROUTER_ADDRESS, amountIn);

        // Log swap configuration
        console.log("\nSwap Configuration:");
        console.log("Router Address:", SWAP_ROUTER_ADDRESS);
        console.log("Token In:", tokenIn);
        console.log("Token Out:", tokenOut);
        console.log("Tick Spacing:", TICK_SPACING);
        console.log("Amount In:", amountIn);
        console.log("Sqrt Price Limit:", SQRT_PRICE_TARGET_X96);

        // Execute swap
        _swap(params);

        // Record and report post-swap balances
        uint256 tokenInBalanceAfter = _getTokenBalance(address(msg.sender), tokenIn);
        uint256 tokenOutBalanceAfter = _getTokenBalance(address(msg.sender), tokenOut);

        console.log("Token In balance after swap:", tokenInBalanceAfter);
        console.log("Token Out balance after swap:", tokenOutBalanceAfter);

        (uint160 sqrtPriceX96After, int24 tickAfter,,,,) = pool.slot0();

        console.log("Sqrt Price X96 after swap:", sqrtPriceX96After);
        console.log("Tick after swap:", tickAfter);
        
        // Verify swap results
        uint256 tokenInUsed = tokenInBalanceBefore - tokenInBalanceAfter;
        uint256 tokenOutReceived = tokenOutBalanceAfter - tokenOutBalanceBefore;
        
        console.log("Swap Results:");
        console.log("Token In used:", tokenInUsed);
        console.log("Token Out received:", tokenOutReceived);

        if (sqrtPriceX96After == SQRT_PRICE_TARGET_X96) {
            console.log("\nAerodrome swap executed successfully, target price reached!");
        } else {
            console.log("\nAerodrome swap executed but target price NOT reached");
        }

        // Burn position
        _burnPosition(24321609, 1);
    }

    
    /**
     * @notice Core mint logic
     */
    function _mintPosition() internal returns (uint256 tokenId, uint128 liquidity) {
        (uint160 currentSqrtPrice,,,,,) = pool.slot0();
        (int24 tickLower, int24 tickUpper) = _computeTickRange(
            currentSqrtPrice,
            SQRT_PRICE_TARGET_X96 
        );

        uint160 sqrtPriceLower = TickMath.getSqrtPriceAtTick(tickLower);
        uint160 sqrtPriceUpper = TickMath.getSqrtPriceAtTick(tickUpper);

        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(currentSqrtPrice, sqrtPriceLower, sqrtPriceUpper, LIQUIDITY);


        console.log("\nMinting new position...");
        console.log("Lower tick:", tickLower);
        console.log("Upper tick:", tickUpper);

        console.log("Amount0:", amount0);
        console.log("Amount1:", amount1);

        // Approve tokens for minting
        IERC20Minimal(TOKEN0).approve(address(nftPositionManager), amount0);
        IERC20Minimal(TOKEN1).approve(address(nftPositionManager), amount1);

        INonfungiblePositionManager.MintParams memory mintParams = INonfungiblePositionManager.MintParams({
            token0: TOKEN0,
            token1: TOKEN1,
            tickSpacing: TICK_SPACING,
            tickLower: tickLower,
            tickUpper: tickUpper,
            amount0Desired: amount0,
            amount1Desired: amount1,
            amount0Min: 0,
            amount1Min: 0,
            recipient: msg.sender,
            deadline: block.timestamp + 30,
            sqrtPriceX96: 0 // pool already created
        });

        (tokenId, liquidity,,) = nftPositionManager.mint(mintParams);
        console.log("Liquidity position %s minted!", tokenId);
    }


    function _burnPosition(uint256 tokenId, uint128 liquidity) internal {

        INonfungiblePositionManager.DecreaseLiquidityParams memory decreaseLiquidityParams = INonfungiblePositionManager.DecreaseLiquidityParams({
            tokenId: tokenId,
            liquidity: liquidity,
            amount0Min: 0,
            amount1Min: 0,
            deadline: block.timestamp + 30
        });

        nftPositionManager.decreaseLiquidity(decreaseLiquidityParams);
        console.log("\nLiquidity position %s burned", tokenId);
    }


    /**
     * @notice Execute a swap through the Aerodrome swap router
     * @param params The swap parameters
     * @return amountOut The amount of tokens received from the swap
     */
    function _swap(
        IAerodromeSwapRouter.ExactInputSingleParams memory params
    ) internal returns (uint256 amountOut) {
        console.log("\nExecuting Aerodrome swap...");
        console.log("Token In:", params.tokenIn);
        console.log("Token Out:", params.tokenOut);
        console.log("Amount In:", params.amountIn);
        console.log("Tick Spacing:", params.tickSpacing);

        amountOut = swapRouter.exactInputSingle(params);

        console.log("Amount Out:", amountOut);
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

        console.log("Current tick:", currentTick);
        console.log("Target tick:", targetTick);

        lower = _roundToSpacing(
            currentTick < targetTick ? currentTick : targetTick,
            false
        );
        upper = _roundToSpacing(
            currentTick < targetTick ? targetTick : currentTick,
            true
        );

        if (upper - lower < TICK_SPACING) {
            upper = lower + TICK_SPACING; // should be safe within bounds since real tick is never on the edges
        }
    }

    /**
     * @notice Rounds a tick to the nearest tick spacing while respecting MIN/MAX tick boundaries
     * @param tick Tick value to round
     * @return Rounded tick aligned to tick spacing and bounded within usable range
     */
    function _roundToSpacing(int24 tick, bool isUpper) internal pure returns (int24) {
        // Calculate the min and max usable ticks for the given tick spacing
        int24 minUsableTick = (TickMath.MIN_TICK / TICK_SPACING) * TICK_SPACING;
        int24 maxUsableTick = (TickMath.MAX_TICK / TICK_SPACING) * TICK_SPACING;
        
        // First align the tick to spacing
        int24 aligned = (tick / TICK_SPACING) * TICK_SPACING + (isUpper ? TICK_SPACING : int24(0));
        if (tick < 0 && tick % TICK_SPACING != 0) {
            aligned -= TICK_SPACING;
        }
        
        // Clamp the aligned tick to the usable bounds
        if (aligned < minUsableTick) {
            aligned = minUsableTick;
        } else if (aligned > maxUsableTick) {
            aligned = maxUsableTick;
        }
        
        return aligned;
    }

    function _checkParameters() internal pure {
        require(TOKEN0 < TOKEN1, "TOKEN0 must be less than TOKEN1");
        require(TICK_SPACING > 0, "TICK_SPACING must be greater than 0");
        require(LIQUIDITY > 1, "LIQUIDITY must be greater than 1");
        require(amountIn > 0, "amountIn must be greater than 0");
        require(SQRT_PRICE_TARGET_X96 > 0, "SQRT_PRICE_TARGET_X96 must be greater than 0");
    }

    /**
     * @notice Get token balance for an account
     * @param account Address to check balance for
     * @param token Token address
     * @return Token balance
     */
    function _getTokenBalance(
        address account,
        address token
    ) internal view returns (uint256) {
        return IERC20Minimal(token).balanceOf(account);
    }

    /**
     * @notice Provide tokens to an address for simulation purposes
     * @param recipient Address to receive tokens
     * @param token Token address
     * @param amount Amount of tokens to provide
     */
    function _dealTokens(
        address recipient,
        address token,
        uint256 amount
    ) internal {
        console.log("\nDealing %s tokens of %s to %s", amount, token, recipient);
        // Use the appropriate token holder for transfer
        address originalHolder = token == TOKEN0
            ? whaleToken0Holder
            : whaleToken1Holder;
        
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
