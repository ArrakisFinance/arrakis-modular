// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// #region foundry.
import {console} from "forge-std/console.sol";
import {TestWrapper} from "../utils/TestWrapper.sol";
// #endregion foundry.

// #region openzeppelin.
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// #endregion openzeppelin.

// #region constants.
import {PIPS} from "../../src/constants/CArrakis.sol";
// #endregion constants.

// #region uniswap v4.

import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";
import {PoolKey, Currency, IHooks} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {LiquidityAmounts} from "@uniswap/v4-periphery/contracts/libraries/LiquidityAmounts.sol";

// #endregion uniswap v4.

// #region mocks.

import {ManagerMock} from "../mocks/ManagerMock.sol";
import {ArrakisMetaVaultMock} from "../mocks/ArrakisMetaVaultMock.sol";

// #endregion mocks.

import {UniV4NativeModule} from "../../src/modules/UniV4NativeModule.sol";
import {IUniV4NativeModule} from "../../src/interfaces/IUniV4NativeModule.sol";
import {IArrakisLPModule} from "../../src/interfaces/IArrakisLPModule.sol";

contract UniV4NativeModuleTest is TestWrapper {
    using PoolIdLibrary for PoolKey;
    // #region constant properties.

    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant UNI = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
    address public constant STETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    uint24 public constant fee = 1000;
    int24 public constant tickSpacing = 10;
    uint256 public constant init0 = 2000e6;
    uint256 public constant init1 = 1e18;

    // #endregion constant properties.

    // #region uniswap v4.

    PoolManager public poolManager;

    // #endregion uniswap v4.

    // #region mocks.

    ManagerMock public manager;
    ArrakisMetaVaultMock public metaVault;

    // #endregion mocks.

    UniV4NativeModule public module;
    PoolKey public poolKey;

    function setUp() public {
        poolManager = new PoolManager(0);

        // #region create a pool.
        uint256 price = 2000;
        poolManager.lock(address(this), abi.encode(price, fee));

        // #endregion create a pool.

        // #region create metaVault.

        metaVault = new ArrakisMetaVaultMock(USDC, WETH);
        manager = new ManagerMock();

        // #endregion create metaVault.

        metaVault.setManager(address(manager));

        // #region create uni v3 native module.

        module = new UniV4NativeModule(
            address(poolManager),
            poolKey,
            address(metaVault),
            USDC,
            WETH,
            init0,
            init1
        );

        // #endregion create uni v3 native module.
    }

    // #region test constructor.

    function test_ConstructorWithPoolManagerZeroAddress() public {
        vm.expectRevert(IArrakisLPModule.AddressZero.selector);

        module = new UniV4NativeModule(
            address(0),
            poolKey,
            address(metaVault),
            USDC,
            WETH,
            init0,
            init1
        );
    }

    function test_ConstructorWithMetaVaultZeroAddress() public {
        vm.expectRevert(IArrakisLPModule.AddressZero.selector);

        module = new UniV4NativeModule(
            address(poolManager),
            poolKey,
            address(0),
            USDC,
            WETH,
            init0,
            init1
        );
    }

    function test_ConstructorWithToken0ZeroAddress() public {
        vm.expectRevert(IArrakisLPModule.AddressZero.selector);

        module = new UniV4NativeModule(
            address(poolManager),
            poolKey,
            address(metaVault),
            address(0),
            WETH,
            init0,
            init1
        );
    }

    function test_ConstructorWithToken1ZeroAddress() public {
        vm.expectRevert(IArrakisLPModule.AddressZero.selector);

        module = new UniV4NativeModule(
            address(poolManager),
            poolKey,
            address(metaVault),
            USDC,
            address(0),
            init0,
            init1
        );
    }

    function test_ConstructorWithToken0GtToken1() public {
        vm.expectRevert(IUniV4NativeModule.Token0GteToken1.selector);

        module = new UniV4NativeModule(
            address(poolManager),
            poolKey,
            address(metaVault),
            WETH,
            USDC,
            init0,
            init1
        );
    }

    function test_ConstructorWithCurrency0DtToken0() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IUniV4NativeModule.Currency0DtToken0.selector,
                USDC,
                UNI
            )
        );

        module = new UniV4NativeModule(
            address(poolManager),
            poolKey,
            address(metaVault),
            UNI,
            WETH,
            init0,
            init1
        );
    }

    function test_ConstructorWithPoolNotInitialized() public {
        vm.expectRevert(IUniV4NativeModule.SqrtPriceZero.selector);

        poolKey = PoolKey({
            currency0: Currency.wrap(UNI),
            currency1: Currency.wrap(STETH),
            fee: fee,
            tickSpacing: tickSpacing,
            hooks: IHooks(address(0))
        });

        module = new UniV4NativeModule(
            address(poolManager),
            poolKey,
            address(metaVault),
            UNI,
            STETH,
            init0,
            init1
        );
    }

    function test_Constructor() public {
        assertEq(address(module.poolManager()), address(poolManager));

        // #region check poolKey.

        (
            Currency currency0,
            Currency currency1,
            uint24 _fee,
            int24 _tickSpacing,
            IHooks hooks
        ) = module.poolKey();

        assertEq(Currency.unwrap(currency0), USDC);
        assertEq(Currency.unwrap(currency1), WETH);
        assertEq(_fee, fee);
        assertEq(_tickSpacing, tickSpacing);
        assertEq(address(hooks), address(0));

        // #endregion check poolKey.
    }

    // #endregion test constructor.

    // #region test setPool functions.

    function test_SetPoolOnlyManager() public {
        poolKey = PoolKey({
            currency0: Currency.wrap(UNI),
            currency1: Currency.wrap(STETH),
            fee: fee,
            tickSpacing: tickSpacing,
            hooks: IHooks(address(0))
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisLPModule.OnlyManager.selector,
                address(this),
                address(manager)
            )
        );

        module.setPool(poolKey);
    }

    function test_SetPoolCurrency0DtToken0() public {
        poolKey = PoolKey({
            currency0: Currency.wrap(UNI),
            currency1: Currency.wrap(STETH),
            fee: fee,
            tickSpacing: tickSpacing,
            hooks: IHooks(address(0))
        });

        vm.prank(address(manager));

        vm.expectRevert(
            abi.encodeWithSelector(
                IUniV4NativeModule.Currency0DtToken0.selector,
                UNI,
                USDC
            )
        );

        module.setPool(poolKey);
    }

    function test_SetPoolCurrency1DtToken1() public {
        poolKey = PoolKey({
            currency0: Currency.wrap(USDC),
            currency1: Currency.wrap(STETH),
            fee: fee,
            tickSpacing: tickSpacing,
            hooks: IHooks(address(0))
        });

        vm.prank(address(manager));

        vm.expectRevert(
            abi.encodeWithSelector(
                IUniV4NativeModule.Currency1DtToken1.selector,
                STETH,
                WETH
            )
        );

        module.setPool(poolKey);
    }

    function test_SetPoolPriceX96Zero() public {
        poolKey = PoolKey({
            currency0: Currency.wrap(USDC),
            currency1: Currency.wrap(WETH),
            fee: 2 * fee,
            tickSpacing: tickSpacing,
            hooks: IHooks(address(0))
        });

        vm.prank(address(manager));

        vm.expectRevert(IUniV4NativeModule.SqrtPriceZero.selector);

        module.setPool(poolKey);
    }

    function test_SetPoolSamePool() public {
        poolKey = PoolKey({
            currency0: Currency.wrap(USDC),
            currency1: Currency.wrap(WETH),
            fee: fee,
            tickSpacing: tickSpacing,
            hooks: IHooks(address(0))
        });

        vm.prank(address(manager));

        vm.expectRevert(IUniV4NativeModule.SamePool.selector);

        module.setPool(poolKey);
    }

    function test_SetPool() public {
        uint256 price = 10;
        poolManager.lock(address(this), abi.encode(price, 2 * fee));

        vm.prank(address(manager));

        module.setPool(poolKey);
    }

    // #endregion test setPool functions.

    // #region test deposit functions.

    function test_DepositOnlyMetaVault() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisLPModule.OnlyMetaVault.selector,
                address(this),
                address(metaVault)
            )
        );

        module.deposit(vm.addr(1), PIPS);
    }

    function test_DepositDepositorAddressZero() public {
        vm.prank(address(metaVault));
        vm.expectRevert(IArrakisLPModule.AddressZero.selector);

        module.deposit(address(0), PIPS);
    }

    function test_DepositProportionZero() public {
        vm.prank(address(metaVault));
        vm.expectRevert(IArrakisLPModule.ProportionZero.selector);

        module.deposit(vm.addr(1), 0);
    }

    function test_Deposit() public {
        address depositor = vm.addr(1);
        uint256 proportion = PIPS;

        deal(USDC, depositor, init0);
        deal(WETH, depositor, init1);

        vm.prank(depositor);
        IERC20(USDC).approve(address(module), init0);
        vm.prank(depositor);
        IERC20(WETH).approve(address(module), init1);

        vm.prank(address(metaVault));
        module.deposit(depositor, proportion);

        assertEq(
            poolManager.balanceOf(address(module), poolKey.currency0),
            init0
        );
        assertEq(
            poolManager.balanceOf(address(module), poolKey.currency1),
            init1
        );
    }

    function test_DepositWithActiveRange() public {
        address depositor = vm.addr(1);
        uint256 proportion = PIPS;

        deal(USDC, depositor, init0);
        deal(WETH, depositor, init1);

        vm.prank(depositor);
        IERC20(USDC).approve(address(module), init0);
        vm.prank(depositor);
        IERC20(WETH).approve(address(module), init1);

        vm.prank(address(metaVault));
        module.deposit(depositor, proportion);

        assertEq(
            poolManager.balanceOf(address(module), poolKey.currency0),
            init0
        );
        assertEq(
            poolManager.balanceOf(address(module), poolKey.currency1),
            init1
        );

        // #region addLiquidity as manager.
        PoolId poolId = poolKey.toId();
        (uint160 sqrtPriceX96, int24 tick, ) = poolManager.getSlot0(poolId);

        int24 tickLower = tick - (tick % tickSpacing) - tickSpacing;
        int24 tickUpper = tick - (tick % tickSpacing) + tickSpacing;
        uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(tickUpper);

        uint128 liquidityToAdd = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            sqrtRatioAX96,
            sqrtRatioBX96,
            init0,
            init1
        );

        vm.prank(address(manager));

        module.addLiquidity(liquidityToAdd, tickLower, tickUpper);

        // #endregion addLiquidity as manager.
    }

    // #endregion test deposit functions.

    // #region test withdraw functions.

    function test_WithdrawOnlyMetaVault() public {
        _deposit();

        address receiver = vm.addr(1);
        uint256 proportion = PIPS;

        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisLPModule.OnlyMetaVault.selector,
                address(this),
                address(metaVault)
            )
        );

        module.withdraw(receiver, proportion);
    }

    function test_WithdrawWithDepositorAddressZero() public {
        _deposit();

        address receiver = address(0);
        uint256 proportion = PIPS;

        vm.prank(address(metaVault));
        vm.expectRevert(IArrakisLPModule.AddressZero.selector);

        module.withdraw(receiver, proportion);
    }

    function test_WithdrawWithProportionZero() public {
        _deposit();

        address receiver = vm.addr(1);
        uint256 proportion = 0;

        vm.prank(address(metaVault));
        vm.expectRevert(IArrakisLPModule.ProportionZero.selector);

        module.withdraw(receiver, proportion);
    }

    function test_WithdrawWithOverBurn() public {
        _deposit();

        address receiver = vm.addr(1);
        uint256 proportion = PIPS + 1;

        vm.prank(address(metaVault));
        vm.expectRevert(IArrakisLPModule.CannotBurnMtTotalSupply.selector);

        module.withdraw(receiver, proportion);
    }

    function test_Withdraw() public {
        (uint256 amount0, uint256 amount1) = _deposit();

        address receiver = vm.addr(20);
        uint256 proportion = PIPS;

        vm.prank(address(metaVault));

        module.withdraw(receiver, proportion);

        assertEq(IERC20(USDC).balanceOf(receiver), amount0);
        assertEq(IERC20(WETH).balanceOf(receiver), amount1);
    }

    function test_WithdrawActiveRange() public {
        (uint256 amount0, uint256 amount1) = _depositWithActiveRange();

        address receiver = vm.addr(20);
        uint256 proportion = PIPS;

        vm.prank(address(metaVault));

        module.withdraw(receiver, proportion);

        /// @dev due to mint (rounding up) and burn (rounding down).
        /// we are 1 wei down from the start.

        assertEq(IERC20(USDC).balanceOf(receiver), amount0 - 1 wei);
        assertEq(IERC20(WETH).balanceOf(receiver), amount1 - 1 wei);
    }

    // #endregion test withdraw functions.

    // #region test add Liquidity.

    function test_AddLiquidityOnlyManager() public {
        address depositor = vm.addr(1);
        uint256 proportion = PIPS;

        deal(USDC, depositor, init0);
        deal(WETH, depositor, init1);

        vm.prank(depositor);
        IERC20(USDC).approve(address(module), init0);
        vm.prank(depositor);
        IERC20(WETH).approve(address(module), init1);

        vm.prank(address(metaVault));
        module.deposit(depositor, proportion);

        assertEq(
            poolManager.balanceOf(address(module), poolKey.currency0),
            init0
        );
        assertEq(
            poolManager.balanceOf(address(module), poolKey.currency1),
            init1
        );

        // #region addLiquidity as manager.
        PoolId poolId = poolKey.toId();
        (uint160 sqrtPriceX96, int24 tick, ) = poolManager.getSlot0(poolId);

        int24 tickLower = tick - (tick % tickSpacing) - tickSpacing;
        int24 tickUpper = tick - (tick % tickSpacing) + tickSpacing;
        uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(tickUpper);

        uint128 liquidityToAdd = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            sqrtRatioAX96,
            sqrtRatioBX96,
            init0,
            init1
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisLPModule.OnlyManager.selector,
                address(this),
                address(manager)
            )
        );

        module.addLiquidity(liquidityToAdd, tickLower, tickUpper);

        // #endregion addLiquidity as manager.
    }

    function test_AddLiquidityZeroLiquidity() public {
        address depositor = vm.addr(1);
        uint256 proportion = PIPS;

        deal(USDC, depositor, init0);
        deal(WETH, depositor, init1);

        vm.prank(depositor);
        IERC20(USDC).approve(address(module), init0);
        vm.prank(depositor);
        IERC20(WETH).approve(address(module), init1);

        vm.prank(address(metaVault));
        module.deposit(depositor, proportion);

        assertEq(
            poolManager.balanceOf(address(module), poolKey.currency0),
            init0
        );
        assertEq(
            poolManager.balanceOf(address(module), poolKey.currency1),
            init1
        );

        // #region addLiquidity as manager.
        PoolId poolId = poolKey.toId();
        (uint160 sqrtPriceX96, int24 tick, ) = poolManager.getSlot0(poolId);

        int24 tickLower = tick - (tick % tickSpacing) - tickSpacing;
        int24 tickUpper = tick - (tick % tickSpacing) + tickSpacing;
        uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(tickUpper);

        uint128 liquidityToAdd = 0;

        vm.expectRevert(IUniV4NativeModule.LiquidityToAddEqZero.selector);
        vm.prank(address(manager));

        module.addLiquidity(liquidityToAdd, tickLower, tickUpper);

        // #endregion addLiquidity as manager.
    }

    function test_AddLiquidityMisorderingTicks() public {
        address depositor = vm.addr(1);
        uint256 proportion = PIPS;

        deal(USDC, depositor, init0);
        deal(WETH, depositor, init1);

        vm.prank(depositor);
        IERC20(USDC).approve(address(module), init0);
        vm.prank(depositor);
        IERC20(WETH).approve(address(module), init1);

        vm.prank(address(metaVault));
        module.deposit(depositor, proportion);

        assertEq(
            poolManager.balanceOf(address(module), poolKey.currency0),
            init0
        );
        assertEq(
            poolManager.balanceOf(address(module), poolKey.currency1),
            init1
        );

        // #region addLiquidity as manager.
        PoolId poolId = poolKey.toId();
        (uint160 sqrtPriceX96, int24 tick, ) = poolManager.getSlot0(poolId);

        int24 tickLower = tick - (tick % tickSpacing) - tickSpacing;
        int24 tickUpper = tick - (tick % tickSpacing) + tickSpacing;
        uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(tickUpper);

        uint128 liquidityToAdd = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            sqrtRatioAX96,
            sqrtRatioBX96,
            init0,
            init1
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IUniV4NativeModule.TicksMisordered.selector,
                tickUpper,
                tickLower
            )
        );
        vm.prank(address(manager));

        module.addLiquidity(liquidityToAdd, tickUpper, tickLower);

        // #endregion addLiquidity as manager.
    }

    function test_AddLiquidityLowerThanMinTick() public {
        address depositor = vm.addr(1);
        uint256 proportion = PIPS;

        deal(USDC, depositor, init0);
        deal(WETH, depositor, init1);

        vm.prank(depositor);
        IERC20(USDC).approve(address(module), init0);
        vm.prank(depositor);
        IERC20(WETH).approve(address(module), init1);

        vm.prank(address(metaVault));
        module.deposit(depositor, proportion);

        assertEq(
            poolManager.balanceOf(address(module), poolKey.currency0),
            init0
        );
        assertEq(
            poolManager.balanceOf(address(module), poolKey.currency1),
            init1
        );

        // #region addLiquidity as manager.
        PoolId poolId = poolKey.toId();
        (uint160 sqrtPriceX96, int24 tick, ) = poolManager.getSlot0(poolId);

        int24 tickLower = tick - (tick % tickSpacing) - tickSpacing;
        int24 tickUpper = tick - (tick % tickSpacing) + tickSpacing;
        uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(tickUpper);

        uint128 liquidityToAdd = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            sqrtRatioAX96,
            sqrtRatioBX96,
            init0,
            init1
        );

        vm.prank(address(manager));
        vm.expectRevert(
            abi.encodeWithSelector(
                IUniV4NativeModule.TickLowerOutOfBounds.selector,
                TickMath.MIN_TICK - 1
            )
        );

        module.addLiquidity(liquidityToAdd, TickMath.MIN_TICK - 1, tickUpper);

        // #endregion addLiquidity as manager.
    }

    function test_AddLiquidityGreaterThanMaxTick() public {
        address depositor = vm.addr(1);
        uint256 proportion = PIPS;

        deal(USDC, depositor, init0);
        deal(WETH, depositor, init1);

        vm.prank(depositor);
        IERC20(USDC).approve(address(module), init0);
        vm.prank(depositor);
        IERC20(WETH).approve(address(module), init1);

        vm.prank(address(metaVault));
        module.deposit(depositor, proportion);

        assertEq(
            poolManager.balanceOf(address(module), poolKey.currency0),
            init0
        );
        assertEq(
            poolManager.balanceOf(address(module), poolKey.currency1),
            init1
        );

        // #region addLiquidity as manager.
        PoolId poolId = poolKey.toId();
        (uint160 sqrtPriceX96, int24 tick, ) = poolManager.getSlot0(poolId);

        int24 tickLower = tick - (tick % tickSpacing) - tickSpacing;
        int24 tickUpper = tick - (tick % tickSpacing) + tickSpacing;
        uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(tickUpper);

        uint128 liquidityToAdd = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            sqrtRatioAX96,
            sqrtRatioBX96,
            init0,
            init1
        );

        vm.prank(address(manager));
        vm.expectRevert(
            abi.encodeWithSelector(
                IUniV4NativeModule.TickUpperOutOfBounds.selector,
                TickMath.MAX_TICK + 1
            )
        );

        module.addLiquidity(liquidityToAdd, tickLower, TickMath.MAX_TICK + 1);

        // #endregion addLiquidity as manager.
    }

    function test_AddLiquidity() public {
        address depositor = vm.addr(1);
        uint256 proportion = PIPS;

        deal(USDC, depositor, init0);
        deal(WETH, depositor, init1);

        vm.prank(depositor);
        IERC20(USDC).approve(address(module), init0);
        vm.prank(depositor);
        IERC20(WETH).approve(address(module), init1);

        vm.prank(address(metaVault));
        module.deposit(depositor, proportion);

        assertEq(
            poolManager.balanceOf(address(module), poolKey.currency0),
            init0
        );
        assertEq(
            poolManager.balanceOf(address(module), poolKey.currency1),
            init1
        );

        // #region addLiquidity as manager.
        PoolId poolId = poolKey.toId();
        (uint160 sqrtPriceX96, int24 tick, ) = poolManager.getSlot0(poolId);

        int24 tickLower = tick - (tick % tickSpacing) - tickSpacing;
        int24 tickUpper = tick - (tick % tickSpacing) + tickSpacing;
        uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(tickUpper);

        uint128 liquidityToAdd = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            sqrtRatioAX96,
            sqrtRatioBX96,
            init0,
            init1
        );

        vm.prank(address(manager));

        module.addLiquidity(liquidityToAdd, tickLower, tickUpper);

        // #endregion addLiquidity as manager.

        uint128 liquidity = poolManager.getLiquidity(
            poolId,
            address(module),
            tickLower,
            tickUpper
        );

        assertEq(liquidity, liquidityToAdd);
    }

    // #endregion test add Liquidity.

    // #region test remove Liquidity.

    function test_RemoveLiquidityOnlyManager() public {
        address depositor = vm.addr(1);
        uint256 proportion = PIPS;

        deal(USDC, depositor, init0);
        deal(WETH, depositor, init1);

        vm.prank(depositor);
        IERC20(USDC).approve(address(module), init0);
        vm.prank(depositor);
        IERC20(WETH).approve(address(module), init1);

        vm.prank(address(metaVault));
        module.deposit(depositor, proportion);

        assertEq(
            poolManager.balanceOf(address(module), poolKey.currency0),
            init0
        );
        assertEq(
            poolManager.balanceOf(address(module), poolKey.currency1),
            init1
        );

        // #region addLiquidity as manager.
        PoolId poolId = poolKey.toId();
        (uint160 sqrtPriceX96, int24 tick, ) = poolManager.getSlot0(poolId);

        int24 tickLower = tick - (tick % tickSpacing) - tickSpacing;
        int24 tickUpper = tick - (tick % tickSpacing) + tickSpacing;
        uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(tickUpper);

        uint128 liquidityToAdd = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            sqrtRatioAX96,
            sqrtRatioBX96,
            init0,
            init1
        );

        vm.prank(address(manager));

        module.addLiquidity(liquidityToAdd, tickLower, tickUpper);

        // #endregion addLiquidity as manager.

        uint128 liquidityToRemove = liquidityToAdd;

        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisLPModule.OnlyManager.selector,
                address(this),
                address(manager)
            )
        );

        module.removeLiquidity(liquidityToRemove, tickLower, tickUpper);
    }

    function test_RemoveLiquidityZero() public {
        address depositor = vm.addr(1);
        uint256 proportion = PIPS;

        deal(USDC, depositor, init0);
        deal(WETH, depositor, init1);

        vm.prank(depositor);
        IERC20(USDC).approve(address(module), init0);
        vm.prank(depositor);
        IERC20(WETH).approve(address(module), init1);

        vm.prank(address(metaVault));
        module.deposit(depositor, proportion);

        assertEq(
            poolManager.balanceOf(address(module), poolKey.currency0),
            init0
        );
        assertEq(
            poolManager.balanceOf(address(module), poolKey.currency1),
            init1
        );

        // #region addLiquidity as manager.
        PoolId poolId = poolKey.toId();
        (uint160 sqrtPriceX96, int24 tick, ) = poolManager.getSlot0(poolId);

        int24 tickLower = tick - (tick % tickSpacing) - tickSpacing;
        int24 tickUpper = tick - (tick % tickSpacing) + tickSpacing;
        uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(tickUpper);

        uint128 liquidityToAdd = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            sqrtRatioAX96,
            sqrtRatioBX96,
            init0,
            init1
        );

        vm.prank(address(manager));

        module.addLiquidity(liquidityToAdd, tickLower, tickUpper);

        // #endregion addLiquidity as manager.

        uint128 liquidityToRemove = 0;

        vm.expectRevert(IUniV4NativeModule.LiquidityToRemoveEqZero.selector);

        vm.prank(address(manager));

        module.removeLiquidity(liquidityToRemove, tickLower, tickUpper);
    }

    function test_RemoveLiquidityNotActiveRange() public {
        address depositor = vm.addr(1);
        uint256 proportion = PIPS;

        deal(USDC, depositor, init0);
        deal(WETH, depositor, init1);

        vm.prank(depositor);
        IERC20(USDC).approve(address(module), init0);
        vm.prank(depositor);
        IERC20(WETH).approve(address(module), init1);

        vm.prank(address(metaVault));
        module.deposit(depositor, proportion);

        assertEq(
            poolManager.balanceOf(address(module), poolKey.currency0),
            init0
        );
        assertEq(
            poolManager.balanceOf(address(module), poolKey.currency1),
            init1
        );

        // #region addLiquidity as manager.
        PoolId poolId = poolKey.toId();
        (uint160 sqrtPriceX96, int24 tick, ) = poolManager.getSlot0(poolId);

        int24 tickLower = tick - (tick % tickSpacing) - tickSpacing;
        int24 tickUpper = tick - (tick % tickSpacing) + tickSpacing;
        uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(tickUpper);

        uint128 liquidityToAdd = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            sqrtRatioAX96,
            sqrtRatioBX96,
            init0,
            init1
        );

        vm.prank(address(manager));

        module.addLiquidity(liquidityToAdd, tickLower, tickUpper);

        // #endregion addLiquidity as manager.

        uint128 liquidityToRemove = liquidityToAdd;

        vm.expectRevert(
            abi.encodeWithSelector(
                IUniV4NativeModule.RangeShouldBeActive.selector,
                tickLower + 1,
                tickUpper + 1
            )
        );

        vm.prank(address(manager));

        module.removeLiquidity(liquidityToRemove, tickLower + 1, tickUpper + 1);
    }

    function test_RemoveLiquidityOverBurn() public {
        address depositor = vm.addr(1);
        uint256 proportion = PIPS;

        deal(USDC, depositor, init0);
        deal(WETH, depositor, init1);

        vm.prank(depositor);
        IERC20(USDC).approve(address(module), init0);
        vm.prank(depositor);
        IERC20(WETH).approve(address(module), init1);

        vm.prank(address(metaVault));
        module.deposit(depositor, proportion);

        assertEq(
            poolManager.balanceOf(address(module), poolKey.currency0),
            init0
        );
        assertEq(
            poolManager.balanceOf(address(module), poolKey.currency1),
            init1
        );

        // #region addLiquidity as manager.
        PoolId poolId = poolKey.toId();
        (uint160 sqrtPriceX96, int24 tick, ) = poolManager.getSlot0(poolId);

        int24 tickLower = tick - (tick % tickSpacing) - tickSpacing;
        int24 tickUpper = tick - (tick % tickSpacing) + tickSpacing;
        uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(tickUpper);

        uint128 liquidityToAdd = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            sqrtRatioAX96,
            sqrtRatioBX96,
            init0,
            init1
        );

        vm.prank(address(manager));

        module.addLiquidity(liquidityToAdd, tickLower, tickUpper);

        // #endregion addLiquidity as manager.

        uint128 liquidityToRemove = liquidityToAdd + 1;

        vm.expectRevert(IUniV4NativeModule.OverBurning.selector);

        vm.prank(address(manager));

        module.removeLiquidity(liquidityToRemove, tickLower, tickUpper);
    }

    // #endregion test remove Liquidity.

    // #region mock functions.

    function lockAcquired(
        address,
        bytes calldata data_
    ) external returns (bytes memory result) {
        /// @dev for removing solhint alert.
        result = "";
        // #region create the poolKey.

        (uint256 _price, uint24 _fee) = abi.decode(data_, (uint256, uint24));

        poolKey = PoolKey({
            currency0: Currency.wrap(USDC),
            currency1: Currency.wrap(WETH),
            fee: _fee,
            tickSpacing: tickSpacing,
            hooks: IHooks(address(0))
        });

        // #endregion create the poolKey.

        poolManager.initialize(poolKey, _computeNewSQRTPrice(_price), "");
    }

    // #endregion mock functions.

    // #region helper functions.

    function _deposit() internal returns (uint256 amount0, uint256 amount1) {
        address depositor = vm.addr(1);
        uint256 proportion = PIPS;

        deal(USDC, depositor, init0);
        deal(WETH, depositor, init1);

        vm.prank(depositor);
        IERC20(USDC).approve(address(module), init0);
        vm.prank(depositor);
        IERC20(WETH).approve(address(module), init1);

        vm.prank(address(metaVault));
        module.deposit(depositor, proportion);

        assertEq(
            poolManager.balanceOf(address(module), poolKey.currency0),
            init0
        );
        assertEq(
            poolManager.balanceOf(address(module), poolKey.currency1),
            init1
        );

        amount0 = init0;
        amount1 = init1;
    }

    function _depositWithActiveRange()
        internal
        returns (uint256 amount0, uint256 amount1)
    {
        address depositor = vm.addr(1);
        uint256 proportion = PIPS;

        deal(USDC, depositor, init0);
        deal(WETH, depositor, init1);

        vm.prank(depositor);
        IERC20(USDC).approve(address(module), init0);
        vm.prank(depositor);
        IERC20(WETH).approve(address(module), init1);

        vm.prank(address(metaVault));
        module.deposit(depositor, proportion);

        assertEq(
            poolManager.balanceOf(address(module), poolKey.currency0),
            init0
        );
        assertEq(
            poolManager.balanceOf(address(module), poolKey.currency1),
            init1
        );

        // #region addLiquidity as manager.
        PoolId poolId = poolKey.toId();
        (uint160 sqrtPriceX96, int24 tick, ) = poolManager.getSlot0(poolId);

        int24 tickLower = tick - (tick % tickSpacing) - tickSpacing;
        int24 tickUpper = tick - (tick % tickSpacing) + tickSpacing;
        uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(tickUpper);

        uint128 liquidityToAdd = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            sqrtRatioAX96,
            sqrtRatioBX96,
            init0,
            init1
        );

        vm.prank(address(manager));

        module.addLiquidity(liquidityToAdd, tickLower, tickUpper);

        // #endregion addLiquidity as manager.

        return (init0, init1);
    }

    function _computeNewSQRTPrice(
        uint256 price_
    ) internal pure returns (uint160 y) {
        y = uint160(_sqrt(price_ * 2 ** 192));
    }

    function _sqrt(uint256 x_) internal pure returns (uint256 y) {
        uint256 z = (x_ + 1) / 2;
        y = x_;
        while (z < y) {
            y = z;
            z = (x_ / z + z) / 2;
        }
    }

    // #endregion helper functions.
}
