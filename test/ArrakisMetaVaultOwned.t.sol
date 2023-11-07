// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {console} from "forge-std/console.sol";

import {TestWrapper} from "./utils/TestWrapper.sol";
import {IArrakisMetaVault} from "../src/interfaces/IArrakisMetaVault.sol";
import {IArrakisMetaOwned} from "../src/interfaces/IArrakisMetaOwned.sol";
import {IArrakisLPModule} from "../src/interfaces/IArrakisLPModule.sol";
import {IUniV3MultiPosition} from "../src/interfaces/IUniV3MultiPosition.sol";
import {ArrakisMetaVaultOwned} from "../src/ArrakisMetaVaultOwned.sol";
import {UniV3MultiPositionWithSwap} from "../src/modules/UniV3MultiPositionWithSwap.sol";
import {OracleWrapperMock} from "./mocks/OracleWrapperMock.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {RangeMintBurn, Range} from "../src/structs/SUniswap.sol";
import {LiquidityAmounts} from "v3-lib-0.8/LiquidityAmounts.sol";
import {TickMath} from "v3-lib-0.8/TickMath.sol";

contract ArrakisMetaVaultOwnedTest is TestWrapper {
    IUniswapV3Factory public constant uniswapV3Factory =
        IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);

    address public vault;
    address public module;
    address public oracle;

    address public token0;
    address public token1;

    address public owner;
    address public manager;

    function setUp() public {
        token0 = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC
        token1 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH
        owner = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045; // vitalik.eth
        manager = 0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B; // VB
        uint256 init0 = 1650_000_000;
        uint256 init1 = 1e18;
        module = address(new UniV3MultiPositionWithSwap(uniswapV3Factory));

        vault = address(
            new ArrakisMetaVaultOwned(
                token0,
                token1,
                owner,
                init0,
                init1,
                module
            )
        );

        oracle = address(new OracleWrapperMock());

        UniV3MultiPositionWithSwap(module).initialize(
            OracleWrapperMock(oracle),
            IArrakisMetaVault(vault),
            IERC20(token0),
            IERC20(token1),
            init0,
            init1
        );
    }

    function test_deposit_withdraw() public {
        deal(token0, owner, 1650_000_000);
        deal(token1, owner, 1e18);

        vm.prank(owner);
        IERC20(token0).approve(vault, 1650_000_000);

        vm.prank(owner);
        IERC20(token1).approve(vault, 1e18);

        uint256 balanceBeforeD0 = IERC20(token0).balanceOf(owner);
        uint256 balanceBeforeD1 = IERC20(token1).balanceOf(owner);

        vm.prank(owner);
        IArrakisMetaOwned(vault).deposit(1_000_000);

        uint256 balanceAfterD0 = IERC20(token0).balanceOf(owner);
        uint256 balanceAfterD1 = IERC20(token1).balanceOf(owner);

        assertEq(balanceAfterD0, 0);
        assertEq(balanceAfterD1, 0);

        vm.prank(owner);
        IArrakisMetaOwned(vault).withdraw(1_000_000, owner);

        uint256 balanceAfterW0 = IERC20(token0).balanceOf(owner);
        uint256 balanceAfterW1 = IERC20(token1).balanceOf(owner);

        assertEq(balanceAfterW0, balanceBeforeD0);
        assertEq(balanceAfterW1, balanceBeforeD1);
    }

    function test_rebalance() public {
        deal(token0, owner, 1650_000_000);
        deal(token1, owner, 1e18);

        vm.prank(owner);
        IERC20(token0).approve(vault, 1650_000_000);

        vm.prank(owner);
        IERC20(token1).approve(vault, 1e18);

        uint256 balanceBeforeD0 = IERC20(token0).balanceOf(owner);
        uint256 balanceBeforeD1 = IERC20(token1).balanceOf(owner);

        vm.prank(owner);
        IArrakisMetaVault(vault).setManager(manager);

        vm.prank(manager);
        IArrakisMetaVault(vault).setManagerFeePIPS(10_000);

        vm.prank(owner);
        IArrakisMetaOwned(vault).deposit(1_000_000);

        address pool = uniswapV3Factory.getPool(token0, token1, 100);

        (, int24 tick, , , , , ) = IUniswapV3Pool(pool).slot0();
        int24 tickSpacing = IUniswapV3Pool(pool).tickSpacing();

        Range memory range = Range({
            lowerTick: tick - 10,
            upperTick: tick + 10,
            feeTier: 100
        });

        uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(tick);
        uint160 sqrtPriceAX96 = TickMath.getSqrtRatioAtTick(tick - 10);
        uint160 sqrtPriceBX96 = TickMath.getSqrtRatioAtTick(tick + 10);

        (uint256 a0, uint256 a1) = UniV3MultiPositionWithSwap(module)
            .totalUnderlying();

        // Let say we want to put 10% of our allocation into univ3.
        a0 = a0 * 10 / 100; 
        a1 = a1 * 10 / 100; 

        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            sqrtPriceAX96,
            sqrtPriceBX96,
            a0,
            a1
        );

        RangeMintBurn[] memory rmBList = new RangeMintBurn[](1);

        rmBList[0] = RangeMintBurn({range: range, liquidity: liquidity});

        bytes[] memory datas = new bytes[](1);
        datas[0] = abi.encodeWithSelector(
            IUniV3MultiPosition.mint.selector,
            rmBList,
            0,
            0
        );

        vm.prank(manager);
        IArrakisMetaVault(vault).rebalance(datas);
    }
}
