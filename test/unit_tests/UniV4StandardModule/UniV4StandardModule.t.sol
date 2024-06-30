// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

// #region foundry.
import {console} from "forge-std/console.sol";
import {TestWrapper} from "../../utils/TestWrapper.sol";
// #endregion foundry.

// #region Uniswap Module.
import {UniV4StandardModule} from
    "../../../src/modules/UniV4StandardModule.sol";
import {IUniV4StandardModule} from
    "../../../src/interfaces/IUniV4StandardModule.sol";
import {IArrakisLPModule} from
    "../../../src/interfaces/IArrakisLPModule.sol";
import {IOracleWrapper} from
    "../../../src/interfaces/IOracleWrapper.sol";
import {BASE} from "../../../src/constants/CArrakis.sol";
// #endregion Uniswap Module.

// #region openzeppelin.
import {SafeERC20} from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeCast} from
    "@openzeppelin/contracts/utils/math/SafeCast.sol";
// #endregion openzeppelin.

// #region uniswap.
import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {FullMath} from "@uniswap/v4-core/src/libraries/FullMath.sol";
import {LiquidityAmounts} from
    "@uniswap/v4-periphery/contracts/libraries/LiquidityAmounts.sol";
// #endregion uniswap.

// #region mock contracts.
import {ArrakisMetaVaultMock} from "./mocks/ArrakisMetaVault.sol";
import {GuardianMock} from "./mocks/Guardian.sol";
import {OracleMock} from "./mocks/OracleWrapperMock.sol";
// #endregion mock contracts.

contract UniV4StandardModuleTest is TestWrapper {
    // #region constants.

    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // #endregion constants.

    PoolManager public poolManager;
    PoolKey public poolKey;
    uint160 public sqrtPriceX96;
    address public manager;
    address public pauser;
    address public metaVault;
    address public guardian;

    UniV4StandardModule public module;

    function setUp() public {
        manager = vm.addr(uint256(keccak256(abi.encode("Manager"))));
        pauser = vm.addr(uint256(keccak256(abi.encode("Pauser"))));

        // #region meta vault creation.

        metaVault = address(new ArrakisMetaVaultMock(manager));

        // #endregion meta vault creation.

        // #region create a guardian.

        guardian = address(new GuardianMock(pauser));

        // #endregion create a guardian.

        // #region do a poolManager deployment.

        poolManager = new PoolManager(0);

        // #region create a pool.

        Currency currency0 = Currency.wrap(USDC);
        Currency currency1 = Currency.wrap(WETH);

        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 10_000,
            tickSpacing: 10,
            hooks: IHooks(address(0))
        });

        sqrtPriceX96 = 1_465_133_142_213_943_882_042_816_409_358_200;

        poolManager.unlock(abi.encode(2));

        // #endregion create a pool.

        // #endregion do a poolManager deployment.

        // #region create uni v4 module.

        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        module = new UniV4StandardModule(
            address(poolManager),
            poolKey,
            metaVault,
            USDC,
            WETH,
            init0,
            init1,
            guardian
        );

        // #endregion create uni v4 module.
    }

    // #region uniswap v4 callback function.

    function unlockCallback(bytes calldata data)
        public
        returns (bytes memory)
    {
        uint256 typeOfLockAcquired = abi.decode(data, (uint256));

        // if (typeOfLockAcquired == 0) _lockAcquiredAddPosition();
        // if (typeOfLockAcquired == 1) _lockAcquiredSwap();
        if (typeOfLockAcquired == 2) {
            poolManager.initialize(poolKey, sqrtPriceX96, "");
        }
    }

    // #endregion uniswap v4 callback function.

    // #region test pause.

    function testPauseOnlyGuardian() public {
        vm.expectRevert(IArrakisLPModule.OnlyGuardian.selector);

        module.pause();
    }

    function testPauser() public {
        assertEq(module.paused(), false);

        vm.prank(pauser);

        module.pause();

        assertEq(module.paused(), true);
    }

    // #endregion test pause.

    // #region test unpause.

    function testUnPauseOnlyGuardian() public {
        // #region pause first.

        assertEq(module.paused(), false);

        vm.prank(pauser);

        module.pause();

        assertEq(module.paused(), true);

        // #endregion pause first.

        vm.expectRevert(IArrakisLPModule.OnlyGuardian.selector);

        module.unpause();
    }

    function testUnPause() public {
        // #region pause first.

        assertEq(module.paused(), false);

        vm.prank(pauser);

        module.pause();

        assertEq(module.paused(), true);

        // #endregion pause first.

        vm.prank(pauser);

        module.unpause();

        assertEq(module.paused(), false);
    }

    // #endregion test unpause.

    // #region test set pool.

    function testSetPoolOnlyManager() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisLPModule.OnlyManager.selector,
                address(this),
                manager
            )
        );

        module.setPool(poolKey);
    }

    function testSetPoolCurrency0DtToken0() public {
        address falseCurrency =
            vm.addr(uint256(keccak256(abi.encode("FalseCurrency"))));

        poolKey.currency0 = Currency.wrap(falseCurrency);

        vm.expectRevert(
            abi.encodeWithSelector(
                IUniV4StandardModule.Currency0DtToken0.selector,
                poolKey.currency0,
                USDC
            )
        );

        vm.prank(manager);
        module.setPool(poolKey);
    }

    function testSetPoolCurrency1DtToken1() public {
        address falseCurrency =
            vm.addr(uint256(keccak256(abi.encode("FalseCurrency"))));

        poolKey.currency1 = Currency.wrap(falseCurrency);

        vm.expectRevert(
            abi.encodeWithSelector(
                IUniV4StandardModule.Currency1DtToken1.selector,
                poolKey.currency1,
                WETH
            )
        );

        vm.prank(manager);
        module.setPool(poolKey);
    }

    function testSetPoolSamePool() public {
        vm.expectRevert(IUniV4StandardModule.SamePool.selector);

        vm.prank(manager);
        module.setPool(poolKey);
    }

    function testSetPool() public {
        poolKey = PoolKey({
            currency0: Currency.wrap(USDC),
            currency1: Currency.wrap(WETH),
            fee: 3000,
            tickSpacing: 10,
            hooks: IHooks(address(0))
        });

        poolManager.unlock(abi.encode(2));

        vm.prank(manager);
        module.setPool(poolKey);
    }

    // #endregion test set pool.

    // #region test deposit.

    function testDepositOnlyMetaVault() public {
        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));

        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisLPModule.OnlyMetaVault.selector,
                address(this),
                address(metaVault)
            )
        );

        module.deposit(depositor, BASE);
    }

    function testDepositDepositorAddressZero() public {
        address depositor = address(0);

        vm.expectRevert(IArrakisLPModule.AddressZero.selector);

        vm.prank(metaVault);

        module.deposit(depositor, BASE);
    }

    function testDepositProportionZero() public {
        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));

        vm.expectRevert(IArrakisLPModule.ProportionZero.selector);

        vm.prank(metaVault);
        module.deposit(depositor, 0);
    }

    function testDeposit() public {
        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));

        deal(USDC, depositor, init0);
        deal(WETH, depositor, init1);

        vm.startPrank(depositor);
        IERC20Metadata(USDC).approve(address(module), init0);
        IERC20Metadata(WETH).approve(address(module), init1);
        vm.stopPrank();

        vm.prank(metaVault);
        module.deposit(depositor, BASE);
    }

    // #endregion test deposit.

    // #region test withdraw.

    function testWithdrawOnlyMetaVault() public {
        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));
        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));

        // #region deposit.

        deal(USDC, depositor, init0);
        deal(WETH, depositor, init1);

        vm.startPrank(depositor);
        IERC20Metadata(USDC).approve(address(module), init0);
        IERC20Metadata(WETH).approve(address(module), init1);
        vm.stopPrank();

        vm.prank(metaVault);
        module.deposit(depositor, BASE);

        // #endregion deposit.

        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisLPModule.OnlyMetaVault.selector,
                address(this),
                metaVault
            )
        );

        module.withdraw(receiver, BASE);
    }

    function testWithdrawAddressZero() public {
        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));
        address receiver = address(0);

        // #region deposit.

        deal(USDC, depositor, init0);
        deal(WETH, depositor, init1);

        vm.startPrank(depositor);
        IERC20Metadata(USDC).approve(address(module), init0);
        IERC20Metadata(WETH).approve(address(module), init1);
        vm.stopPrank();

        vm.prank(metaVault);
        module.deposit(depositor, BASE);

        // #endregion deposit.

        vm.expectRevert(IArrakisLPModule.AddressZero.selector);

        vm.prank(metaVault);
        module.withdraw(receiver, BASE);
    }

    function testWithdrawProportionZero() public {
        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));
        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));

        // #region deposit.

        deal(USDC, depositor, init0);
        deal(WETH, depositor, init1);

        vm.startPrank(depositor);
        IERC20Metadata(USDC).approve(address(module), init0);
        IERC20Metadata(WETH).approve(address(module), init1);
        vm.stopPrank();

        vm.prank(metaVault);
        module.deposit(depositor, BASE);

        // #endregion deposit.

        vm.expectRevert(IArrakisLPModule.ProportionZero.selector);

        vm.prank(metaVault);
        module.withdraw(receiver, 0);
    }

    function testWithdraw() public {
        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));
        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));

        // #region deposit.

        deal(USDC, depositor, init0);
        deal(WETH, depositor, init1);

        vm.startPrank(depositor);
        IERC20Metadata(USDC).approve(address(module), init0);
        IERC20Metadata(WETH).approve(address(module), init1);
        vm.stopPrank();

        vm.prank(metaVault);
        module.deposit(depositor, BASE);

        // #endregion deposit.

        assertEq(IERC20Metadata(USDC).balanceOf(depositor), 0);
        assertEq(IERC20Metadata(WETH).balanceOf(depositor), 0);

        vm.prank(metaVault);
        module.withdraw(receiver, BASE);

        assertEq(IERC20Metadata(USDC).balanceOf(receiver), init0);
        assertEq(IERC20Metadata(WETH).balanceOf(receiver), init1);
    }

    // #endregion test withdraw.

    // #region test rebalance.

    function testRebalance() public {
        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));
        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));

        // #region deposit.

        deal(USDC, depositor, init0);
        deal(WETH, depositor, init1);

        vm.startPrank(depositor);
        IERC20Metadata(USDC).approve(address(module), init0);
        IERC20Metadata(WETH).approve(address(module), init1);
        vm.stopPrank();

        vm.prank(metaVault);
        module.deposit(depositor, BASE);

        // #endregion deposit.

        assertEq(IERC20Metadata(USDC).balanceOf(depositor), 0);
        assertEq(IERC20Metadata(WETH).balanceOf(depositor), 0);

        // #region do rebalance.

        int24 tick = TickMath.getTickAtSqrtPrice(sqrtPriceX96);

        int24 tickLower = (tick / 10) * 10 - (2 * 10);
        int24 tickUpper = (tick / 10) * 10 + (2 * 10);

        IUniV4StandardModule.Range memory range = IUniV4StandardModule
            .Range({tickLower: tickLower, tickUpper: tickUpper});

        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            init0,
            init1
        );

        IUniV4StandardModule.LiquidityRange memory liquidityRange =
        IUniV4StandardModule.LiquidityRange({
            range: range,
            liquidity: SafeCast.toInt128(
                SafeCast.toInt256(uint256(liquidity))
            )
        });

        IUniV4StandardModule.LiquidityRange[] memory liquidityRanges =
            new IUniV4StandardModule.LiquidityRange[](1);

        liquidityRanges[0] = liquidityRange;

        vm.prank(manager);
        module.rebalance(liquidityRanges);

        // #endregion do rebalance.

        // #region withdraw.

        vm.prank(metaVault);
        module.withdraw(receiver, BASE);

        assertEq(IERC20Metadata(USDC).balanceOf(receiver), init0 - 1);
        assertEq(IERC20Metadata(WETH).balanceOf(receiver), init1 - 1);

        // #endregion withdraw.
    }

    // #endregion test rebalance.

    // #region test guardian.

    function testGuardian() public {
        address actualPauser = module.guardian();

        assertEq(actualPauser, pauser);
    }

    // #endregion test guardian.

    // #region test getRanges.

    function testGetRanges() public {
        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));
        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));

        // #region deposit.

        deal(USDC, depositor, init0);
        deal(WETH, depositor, init1);

        vm.startPrank(depositor);
        IERC20Metadata(USDC).approve(address(module), init0);
        IERC20Metadata(WETH).approve(address(module), init1);
        vm.stopPrank();

        vm.prank(metaVault);
        module.deposit(depositor, BASE);

        // #endregion deposit.

        assertEq(IERC20Metadata(USDC).balanceOf(depositor), 0);
        assertEq(IERC20Metadata(WETH).balanceOf(depositor), 0);

        // #region do rebalance.

        int24 tick = TickMath.getTickAtSqrtPrice(sqrtPriceX96);

        int24 tickLower = (tick / 10) * 10 - (2 * 10);
        int24 tickUpper = (tick / 10) * 10 + (2 * 10);

        IUniV4StandardModule.Range memory range = IUniV4StandardModule
            .Range({tickLower: tickLower, tickUpper: tickUpper});

        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            init0,
            init1
        );

        IUniV4StandardModule.LiquidityRange memory liquidityRange =
        IUniV4StandardModule.LiquidityRange({
            range: range,
            liquidity: SafeCast.toInt128(
                SafeCast.toInt256(uint256(liquidity))
            )
        });

        IUniV4StandardModule.LiquidityRange[] memory liquidityRanges =
            new IUniV4StandardModule.LiquidityRange[](1);

        liquidityRanges[0] = liquidityRange;

        vm.prank(manager);
        module.rebalance(liquidityRanges);

        // #endregion do rebalance.

        IUniV4StandardModule.Range[] memory ranges =
            module.getRanges();

        assertEq(ranges[0].tickLower, tickLower);
        assertEq(ranges[0].tickUpper, tickUpper);
    }

    // #endregion test getRanges.

    // #region test getInits.

    function testGetInits() public {
        (uint256 init0, uint256 init1) = module.getInits();

        assertEq(init0, 3000e6);
        assertEq(init1, 1e18);
    }

    // #endregion test getInits.

    // #region test totalUnderlying.

    function testTotalUnderlying() public {
        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));
        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));

        // #region deposit.

        deal(USDC, depositor, init0);
        deal(WETH, depositor, init1);

        vm.startPrank(depositor);
        IERC20Metadata(USDC).approve(address(module), init0);
        IERC20Metadata(WETH).approve(address(module), init1);
        vm.stopPrank();

        vm.prank(metaVault);
        module.deposit(depositor, BASE);

        // #endregion deposit.

        assertEq(IERC20Metadata(USDC).balanceOf(depositor), 0);
        assertEq(IERC20Metadata(WETH).balanceOf(depositor), 0);

        // #region do rebalance.

        int24 tick = TickMath.getTickAtSqrtPrice(sqrtPriceX96);

        int24 tickLower = (tick / 10) * 10 - (2 * 10);
        int24 tickUpper = (tick / 10) * 10 + (2 * 10);

        IUniV4StandardModule.Range memory range = IUniV4StandardModule
            .Range({tickLower: tickLower, tickUpper: tickUpper});

        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            init0,
            init1
        );

        IUniV4StandardModule.LiquidityRange memory liquidityRange =
        IUniV4StandardModule.LiquidityRange({
            range: range,
            liquidity: SafeCast.toInt128(
                SafeCast.toInt256(uint256(liquidity))
            )
        });

        IUniV4StandardModule.LiquidityRange[] memory liquidityRanges =
            new IUniV4StandardModule.LiquidityRange[](1);

        liquidityRanges[0] = liquidityRange;

        vm.prank(manager);
        module.rebalance(liquidityRanges);

        // #endregion do rebalance.

        (uint256 amount0, uint256 amount1) = module.totalUnderlying();

        assert(
            amount0 > init0
                ? amount0 - init0 <= 1
                : init0 - amount0 <= 1
        );
        assert(
            amount1 > init1
                ? amount1 - init1 <= 1
                : init1 - amount1 <= 1
        );
    }

    // #endregion test totalUnderlying.

    // #region test totalUnderlyingAtPrice.

    function testTotalUnderlyingAtPrice() public {
        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));
        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));

        // #region deposit.

        deal(USDC, depositor, init0);
        deal(WETH, depositor, init1);

        vm.startPrank(depositor);
        IERC20Metadata(USDC).approve(address(module), init0);
        IERC20Metadata(WETH).approve(address(module), init1);
        vm.stopPrank();

        vm.prank(metaVault);
        module.deposit(depositor, BASE);

        // #endregion deposit.

        assertEq(IERC20Metadata(USDC).balanceOf(depositor), 0);
        assertEq(IERC20Metadata(WETH).balanceOf(depositor), 0);

        // #region do rebalance.

        int24 tick = TickMath.getTickAtSqrtPrice(sqrtPriceX96);

        int24 tickLower = (tick / 10) * 10 - (2 * 10);
        int24 tickUpper = (tick / 10) * 10 + (2 * 10);

        IUniV4StandardModule.Range memory range = IUniV4StandardModule
            .Range({tickLower: tickLower, tickUpper: tickUpper});

        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            init0,
            init1
        );

        IUniV4StandardModule.LiquidityRange memory liquidityRange =
        IUniV4StandardModule.LiquidityRange({
            range: range,
            liquidity: SafeCast.toInt128(
                SafeCast.toInt256(uint256(liquidity))
            )
        });

        IUniV4StandardModule.LiquidityRange[] memory liquidityRanges =
            new IUniV4StandardModule.LiquidityRange[](1);

        liquidityRanges[0] = liquidityRange;

        vm.prank(manager);
        module.rebalance(liquidityRanges);

        // #endregion do rebalance.

        // #region compute new price.

        int24 newTick = tick + 10;

        uint160 newSqrtPrice = TickMath.getSqrtPriceAtTick(newTick);

        // #endregion compute new price.

        (uint256 amount0, uint256 amount1) =
            module.totalUnderlyingAtPrice(newSqrtPrice);

        assert(amount0 < init0);
        assert(amount1 > init1);
    }

    // #endregion test totalUnderlyingAtPrice.

    // #region test validateRebalance.

    function testValidateRebalanceOverMaxDeviation() public {
        // #region compute oracle price.
        uint256 oraclePrice;

        uint8 decimals0 = IERC20Metadata(USDC).decimals();

        if (sqrtPriceX96 <= type(uint128).max) {
            oraclePrice = FullMath.mulDiv(
                uint256(sqrtPriceX96) * uint256(sqrtPriceX96),
                10 ** decimals0,
                1 << 192
            );
        } else {
            oraclePrice = FullMath.mulDiv(
                FullMath.mulDiv(
                    uint256(sqrtPriceX96),
                    uint256(sqrtPriceX96),
                    1 << 64
                ),
                10 ** decimals0,
                1 << 128
            );
        }

        oraclePrice = FullMath.mulDiv(oraclePrice, 99, 100);

        OracleMock oracle = new OracleMock();

        oracle.setPrice0(oraclePrice);

        uint24 maxDeviation = 5000;

        vm.expectRevert(
            IUniV4StandardModule.OverMaxDeviation.selector
        );
        module.validateRebalance(
            IOracleWrapper(address(oracle)), maxDeviation
        );

        // #endregion compute oracle price.
    }

    function testValidateRebalance() public {
        poolKey = PoolKey({
            currency0: Currency.wrap(USDC),
            currency1: Currency.wrap(WETH),
            fee: 10_000,
            tickSpacing: 20,
            hooks: IHooks(address(0))
        });

        sqrtPriceX96 = uint160(type(uint128).max) + 1;

        poolManager.unlock(abi.encode(2));

        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        module = new UniV4StandardModule(
            address(poolManager),
            poolKey,
            metaVault,
            USDC,
            WETH,
            init0,
            init1,
            guardian
        );

        // #region compute oracle price.
        uint256 oraclePrice;

        uint8 decimals0 = IERC20Metadata(USDC).decimals();

        if (sqrtPriceX96 <= type(uint128).max) {
            oraclePrice = FullMath.mulDiv(
                uint256(sqrtPriceX96) * uint256(sqrtPriceX96),
                10 ** decimals0,
                1 << 192
            );
        } else {
            oraclePrice = FullMath.mulDiv(
                FullMath.mulDiv(
                    uint256(sqrtPriceX96),
                    uint256(sqrtPriceX96),
                    1 << 64
                ),
                10 ** decimals0,
                1 << 128
            );
        }

        oraclePrice = FullMath.mulDiv(oraclePrice, 99, 100);

        OracleMock oracle = new OracleMock();

        oracle.setPrice0(oraclePrice);

        uint24 maxDeviation = 10_010;

        vm.expectRevert(
            IUniV4StandardModule.OverMaxDeviation.selector
        );
        module.validateRebalance(
            IOracleWrapper(address(oracle)), maxDeviation
        );

        // #endregion compute oracle price.
    }

    // #endregion test validateRebalance.
}
