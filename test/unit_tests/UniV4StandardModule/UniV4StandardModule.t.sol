// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

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
import {IOwnable} from "../../../src/interfaces/IOwnable.sol";
import {
    BASE,
    PIPS,
    NATIVE_COIN
} from "../../../src/constants/CArrakis.sol";
// #endregion Uniswap Module.

// #region openzeppelin.
import {SafeERC20} from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeCast} from
    "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {ERC1967Proxy} from
    "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
// #endregion openzeppelin.

// #region uniswap.
import {IPoolManager} from
    "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";
import {
    Currency,
    CurrencyLibrary
} from "@uniswap/v4-core/src/types/Currency.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {FullMath} from "@uniswap/v4-core/src/libraries/FullMath.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {StateLibrary} from
    "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {TransientStateLibrary} from
    "@uniswap/v4-core/src/libraries/TransientStateLibrary.sol";
// #endregion uniswap.

import {LiquidityAmounts} from
    "@v3-lib-0.8/contracts/LiquidityAmounts.sol";

// #region mock contracts.
import {ArrakisMetaVaultMock} from "./mocks/ArrakisMetaVault.sol";
import {GuardianMock} from "./mocks/Guardian.sol";
import {OracleMock} from "./mocks/OracleWrapperMock.sol";
import {SimpleHook} from "./mocks/SimpleHook.sol";
// #endregion mock contracts.

contract UniV4StandardModuleTest is TestWrapper {
    using StateLibrary for IPoolManager;
    using TransientStateLibrary for IPoolManager;

    // #region constants.

    address public constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDT =
        0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public constant WETH =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // #endregion constants.

    PoolManager public poolManager;
    PoolKey public poolKey;
    uint160 public sqrtPriceX96;
    address public manager;
    address public pauser;
    address public metaVault;
    address public guardian;
    address public owner;

    UniV4StandardModule public module;

    function setUp() public {
        manager = vm.addr(uint256(keccak256(abi.encode("Manager"))));
        pauser = vm.addr(uint256(keccak256(abi.encode("Pauser"))));
        owner = vm.addr(uint256(keccak256(abi.encode("Owner"))));

        // #region meta vault creation.

        metaVault = address(new ArrakisMetaVaultMock(manager, owner));
        ArrakisMetaVaultMock(metaVault).setTokens(USDC, WETH);

        // #endregion meta vault creation.

        // #region create a guardian.

        guardian = address(new GuardianMock(pauser));

        // #endregion create a guardian.

        // #region do a poolManager deployment.

        poolManager = new PoolManager();

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

        sqrtPriceX96 = 1_356_476_084_642_877_807_665_053_548_195_417;

        poolManager.unlock(abi.encode(2));

        // #endregion create a pool.

        // #endregion do a poolManager deployment.

        // #region create uni v4 module.

        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        address implmentation = address(
            new UniV4StandardModule(address(poolManager), guardian)
        );

        bytes memory data = abi.encodeWithSelector(
            IUniV4StandardModule.initialize.selector,
            init0,
            init1,
            false,
            poolKey,
            metaVault
        );

        module = UniV4StandardModule(
            payable(address(new ERC1967Proxy(implmentation, data)))
        );

        vm.prank(address(manager));
        module.setManagerFeePIPS(10_000);

        // #endregion create uni v4 module.
    }

    // #region uniswap v4 callback function.

    function unlockCallback(
        bytes calldata data
    ) public returns (bytes memory) {
        uint256 typeOfLockAcquired = abi.decode(data, (uint256));

        // if (typeOfLockAcquired == 0) _lockAcquiredAddPosition();
        if (typeOfLockAcquired == 1) {
            _lockAcquiredSwap();
        }
        if (typeOfLockAcquired == 2) {
            poolManager.initialize(poolKey, sqrtPriceX96, "");
        }

        if (typeOfLockAcquired == 3) {
            _lockAcquiredSwapBis();
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

    // #region test constructor.

    function testConstructorPoolManagerAddressZero() public {
        vm.expectRevert(IArrakisLPModule.AddressZero.selector);
        new UniV4StandardModule(address(0), guardian);
    }

    function testConstructorMetaVaultAddressZero() public {
        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        address implmentation = address(
            new UniV4StandardModule(address(poolManager), guardian)
        );

        bytes memory data = abi.encodeWithSelector(
            IUniV4StandardModule.initialize.selector,
            init0,
            init1,
            false,
            poolKey,
            address(0)
        );

        vm.expectRevert(IArrakisLPModule.AddressZero.selector);
        module = UniV4StandardModule(
            payable(address(new ERC1967Proxy(implmentation, data)))
        );
    }

    function testConstructorGuardianAddressZero() public {
        vm.expectRevert(IArrakisLPModule.AddressZero.selector);
        new UniV4StandardModule(address(poolManager), address(0));
    }

    function testConstructorCurrency0DtToken0() public {
        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        Currency currency0 = Currency.wrap(WETH);
        Currency currency1 = Currency.wrap(USDT);

        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 10_000,
            tickSpacing: 10,
            hooks: IHooks(address(0))
        });

        poolManager.unlock(abi.encode(2));

        address implmentation = address(
            new UniV4StandardModule(address(poolManager), guardian)
        );

        bytes memory data = abi.encodeWithSelector(
            IUniV4StandardModule.initialize.selector,
            init0,
            init1,
            false,
            poolKey,
            metaVault
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IUniV4StandardModule.Currency0DtToken0.selector,
                WETH,
                USDC
            )
        );
        module = UniV4StandardModule(
            payable(address(new ERC1967Proxy(implmentation, data)))
        );
    }

    function testConstructorCurrency0DtToken0Bis() public {
        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        Currency currency0 = Currency.wrap(WETH);
        Currency currency1 = Currency.wrap(USDT);

        ArrakisMetaVaultMock(metaVault).setTokens(NATIVE_COIN, USDT);

        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 10_000,
            tickSpacing: 10,
            hooks: IHooks(address(0))
        });

        poolManager.unlock(abi.encode(2));

        address implmentation = address(
            new UniV4StandardModule(address(poolManager), guardian)
        );

        bytes memory data = abi.encodeWithSelector(
            IUniV4StandardModule.initialize.selector,
            init0,
            init1,
            false,
            poolKey,
            metaVault
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IUniV4StandardModule.Currency0DtToken0.selector,
                WETH,
                NATIVE_COIN
            )
        );
        module = UniV4StandardModule(
            payable(address(new ERC1967Proxy(implmentation, data)))
        );
    }

    function testConstructorCurrency1DtToken1() public {
        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        Currency currency0 = Currency.wrap(USDC);
        Currency currency1 = Currency.wrap(USDT);

        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 10_000,
            tickSpacing: 10,
            hooks: IHooks(address(0))
        });

        poolManager.unlock(abi.encode(2));

        address implmentation = address(
            new UniV4StandardModule(address(poolManager), guardian)
        );

        bytes memory data = abi.encodeWithSelector(
            IUniV4StandardModule.initialize.selector,
            init0,
            init1,
            false,
            poolKey,
            metaVault
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IUniV4StandardModule.Currency1DtToken1.selector,
                USDT,
                WETH
            )
        );
        module = UniV4StandardModule(
            payable(address(new ERC1967Proxy(implmentation, data)))
        );
    }

    function testConstructorCurrency1DtToken0() public {
        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        Currency currency0 = Currency.wrap(USDC);
        Currency currency1 = Currency.wrap(USDT);

        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 10_000,
            tickSpacing: 10,
            hooks: IHooks(address(0))
        });

        poolManager.unlock(abi.encode(2));

        address implmentation = address(
            new UniV4StandardModule(address(poolManager), guardian)
        );

        bytes memory data = abi.encodeWithSelector(
            IUniV4StandardModule.initialize.selector,
            init0,
            init1,
            true,
            poolKey,
            metaVault
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IUniV4StandardModule.Currency1DtToken0.selector,
                USDT,
                USDC
            )
        );
        module = UniV4StandardModule(
            payable(address(new ERC1967Proxy(implmentation, data)))
        );
    }

    function testConstructorCurrency0DtToken1() public {
        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        Currency currency0 = Currency.wrap(address(1));
        Currency currency1 = Currency.wrap(USDC);

        ArrakisMetaVaultMock(metaVault).setTokens(USDC, NATIVE_COIN);

        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 10_000,
            tickSpacing: 10,
            hooks: IHooks(address(0))
        });

        poolManager.unlock(abi.encode(2));

        address implmentation = address(
            new UniV4StandardModule(address(poolManager), guardian)
        );

        bytes memory data = abi.encodeWithSelector(
            IUniV4StandardModule.initialize.selector,
            init0,
            init1,
            true,
            poolKey,
            metaVault
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IUniV4StandardModule.Currency0DtToken1.selector,
                address(1),
                NATIVE_COIN
            )
        );
        module = UniV4StandardModule(
            payable(address(new ERC1967Proxy(implmentation, data)))
        );
    }

    function testConstructorCurrency0DtToken1Bis() public {
        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        Currency currency0 = Currency.wrap(address(1));
        Currency currency1 = Currency.wrap(USDC);

        ArrakisMetaVaultMock(metaVault).setTokens(USDC, WETH);

        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 10_000,
            tickSpacing: 10,
            hooks: IHooks(address(0))
        });

        poolManager.unlock(abi.encode(2));

        address implmentation = address(
            new UniV4StandardModule(address(poolManager), guardian)
        );

        bytes memory data = abi.encodeWithSelector(
            IUniV4StandardModule.initialize.selector,
            init0,
            init1,
            true,
            poolKey,
            metaVault
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IUniV4StandardModule.Currency0DtToken1.selector,
                address(1),
                WETH
            )
        );
        module = UniV4StandardModule(
            payable(address(new ERC1967Proxy(implmentation, data)))
        );
    }

    function testConstructorNativeCoinCannotBeToken1() public {
        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        Currency currency0 = Currency.wrap(USDC);
        Currency currency1 = Currency.wrap(USDT);

        ArrakisMetaVaultMock(metaVault).setTokens(NATIVE_COIN, USDC);

        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 10_000,
            tickSpacing: 10,
            hooks: IHooks(address(0))
        });

        poolManager.unlock(abi.encode(2));

        address implmentation = address(
            new UniV4StandardModule(address(poolManager), guardian)
        );

        bytes memory data = abi.encodeWithSelector(
            IUniV4StandardModule.initialize.selector,
            init0,
            init1,
            true,
            poolKey,
            metaVault
        );

        vm.expectRevert(
            IUniV4StandardModule.NativeCoinCannotBeToken1.selector
        );
        module = UniV4StandardModule(
            payable(address(new ERC1967Proxy(implmentation, data)))
        );
    }

    function testConstructorNativeCoinCannotBeToken1Bis() public {
        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        Currency currency0 = Currency.wrap(USDC);
        Currency currency1 = Currency.wrap(USDT);

        ArrakisMetaVaultMock(metaVault).setTokens(USDC, NATIVE_COIN);

        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 10_000,
            tickSpacing: 10,
            hooks: IHooks(address(0))
        });

        poolManager.unlock(abi.encode(2));

        address implmentation = address(
            new UniV4StandardModule(address(poolManager), guardian)
        );

        bytes memory data = abi.encodeWithSelector(
            IUniV4StandardModule.initialize.selector,
            init0,
            init1,
            false,
            poolKey,
            metaVault
        );

        vm.expectRevert(
            IUniV4StandardModule.NativeCoinCannotBeToken1.selector
        );
        module = UniV4StandardModule(
            payable(address(new ERC1967Proxy(implmentation, data)))
        );
    }

    function testConstructorNoModifyLiquidityHooksBefore() public {
        SimpleHook hook = SimpleHook(
            address(uint160(Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG))
        );

        SimpleHook implementation = new SimpleHook();

        vm.etch(address(hook), address(implementation).code);

        ArrakisMetaVaultMock(metaVault).setTokens(USDC, USDT);
        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        Currency currency0 = Currency.wrap(USDC);
        Currency currency1 = Currency.wrap(USDT);

        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 10_000,
            tickSpacing: 10,
            hooks: IHooks(address(hook))
        });

        poolManager.unlock(abi.encode(2));

        address implmentation = address(
            new UniV4StandardModule(address(poolManager), guardian)
        );

        bytes memory data = abi.encodeWithSelector(
            IUniV4StandardModule.initialize.selector,
            init0,
            init1,
            false,
            poolKey,
            metaVault
        );

        vm.expectRevert(
            IUniV4StandardModule.NoModifyLiquidityHooks.selector
        );
        module = UniV4StandardModule(
            payable(address(new ERC1967Proxy(implmentation, data)))
        );
    }

    function testConstructorNoModifyLiquidityHooksAfter() public {
        SimpleHook hook = SimpleHook(
            address(uint160(Hooks.AFTER_REMOVE_LIQUIDITY_FLAG))
        );

        SimpleHook implementation = new SimpleHook();

        vm.etch(address(hook), address(implementation).code);

        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        Currency currency0 = Currency.wrap(USDC);
        Currency currency1 = Currency.wrap(WETH);

        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 10_000,
            tickSpacing: 10,
            hooks: IHooks(address(hook))
        });

        poolManager.unlock(abi.encode(2));
        address implmentation = address(
            new UniV4StandardModule(address(poolManager), guardian)
        );

        bytes memory data = abi.encodeWithSelector(
            IUniV4StandardModule.initialize.selector,
            init0,
            init1,
            false,
            poolKey,
            metaVault
        );

        vm.expectRevert(
            IUniV4StandardModule.NoModifyLiquidityHooks.selector
        );
        module = UniV4StandardModule(
            payable(address(new ERC1967Proxy(implmentation, data)))
        );
    }

    function testConstructorSqrtPriceZero() public {
        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        Currency currency0 = Currency.wrap(USDC);
        Currency currency1 = Currency.wrap(USDT);

        ArrakisMetaVaultMock(metaVault).setTokens(USDC, USDT);
        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 10_000,
            tickSpacing: 20,
            hooks: IHooks(address(0))
        });

        address implmentation = address(
            new UniV4StandardModule(address(poolManager), guardian)
        );

        bytes memory data = abi.encodeWithSelector(
            IUniV4StandardModule.initialize.selector,
            init0,
            init1,
            false,
            poolKey,
            metaVault
        );

        vm.expectRevert(IUniV4StandardModule.SqrtPriceZero.selector);
        module = UniV4StandardModule(
            payable(address(new ERC1967Proxy(implmentation, data)))
        );
    }

    // #endregion test constructor.

    // #region test set pool.

    function testSetPoolOnlyManager() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisLPModule.OnlyManager.selector,
                address(this),
                manager
            )
        );

        IUniV4StandardModule.LiquidityRange[] memory liquidityRange =
            new IUniV4StandardModule.LiquidityRange[](0);

        module.setPool(poolKey, liquidityRange);
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

        IUniV4StandardModule.LiquidityRange[] memory liquidityRange =
            new IUniV4StandardModule.LiquidityRange[](0);

        vm.prank(manager);
        module.setPool(poolKey, liquidityRange);
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

        IUniV4StandardModule.LiquidityRange[] memory liquidityRange =
            new IUniV4StandardModule.LiquidityRange[](0);

        vm.prank(manager);
        module.setPool(poolKey, liquidityRange);
    }

    function testSetPoolSamePool() public {
        IUniV4StandardModule.LiquidityRange[] memory liquidityRange =
            new IUniV4StandardModule.LiquidityRange[](0);

        vm.expectRevert(IUniV4StandardModule.SamePool.selector);

        vm.prank(manager);
        module.setPool(poolKey, liquidityRange);
    }

    function testSetPoolNoModifyLiquidityHooks() public {
        SimpleHook hook = SimpleHook(
            address(uint160(Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG))
        );

        SimpleHook implementation = new SimpleHook();

        vm.etch(address(hook), address(implementation).code);

        poolKey = PoolKey({
            currency0: Currency.wrap(USDC),
            currency1: Currency.wrap(WETH),
            fee: 3000,
            tickSpacing: 10,
            hooks: IHooks(address(hook))
        });

        poolManager.unlock(abi.encode(2));

        IUniV4StandardModule.LiquidityRange[] memory liquidityRange =
            new IUniV4StandardModule.LiquidityRange[](0);

        vm.expectRevert(
            IUniV4StandardModule.NoModifyLiquidityHooks.selector
        );
        vm.prank(manager);
        module.setPool(poolKey, liquidityRange);
    }

    function testSetPoolSqrtPriceZero() public {
        poolKey = PoolKey({
            currency0: Currency.wrap(USDC),
            currency1: Currency.wrap(WETH),
            fee: 3000,
            tickSpacing: 10,
            hooks: IHooks(address(0))
        });

        IUniV4StandardModule.LiquidityRange[] memory liquidityRange =
            new IUniV4StandardModule.LiquidityRange[](0);

        vm.expectRevert(IUniV4StandardModule.SqrtPriceZero.selector);
        vm.prank(manager);
        module.setPool(poolKey, liquidityRange);
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

        IUniV4StandardModule.LiquidityRange[] memory liquidityRange =
            new IUniV4StandardModule.LiquidityRange[](0);

        vm.prank(manager);
        module.setPool(poolKey, liquidityRange);
    }

    function testSetPoolRemoveRange() public {
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

        poolKey = PoolKey({
            currency0: Currency.wrap(USDC),
            currency1: Currency.wrap(WETH),
            fee: 3000,
            tickSpacing: 10,
            hooks: IHooks(address(0))
        });

        poolManager.unlock(abi.encode(2));

        IUniV4StandardModule.LiquidityRange[] memory l =
            new IUniV4StandardModule.LiquidityRange[](0);

        vm.prank(manager);
        module.setPool(poolKey, l);
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

    function testDepositActiveRange() public {
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

        // #region second deposit.

        address secondDepositor =
            vm.addr(uint256(keccak256(abi.encode("Second deposit"))));

        (uint256 amount0, uint256 amount1) = module.totalUnderlying();

        amount0 = amount0 + 1;
        amount1 = amount1 + 1;

        deal(USDC, secondDepositor, amount0);
        deal(WETH, secondDepositor, amount1);

        vm.startPrank(secondDepositor);
        IERC20Metadata(USDC).approve(address(module), amount0);
        IERC20Metadata(WETH).approve(address(module), amount1);
        vm.stopPrank();

        vm.prank(metaVault);
        module.deposit(secondDepositor, BASE);

        // #endregion second deposit.
    }

    function testDepositActiveRangeBis() public {
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
            100,
            100
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

        // #region second deposit.

        address secondDepositor =
            vm.addr(uint256(keccak256(abi.encode("Second deposit"))));

        (uint256 amount0, uint256 amount1) = module.totalUnderlying();

        amount0 = (amount0 / 10) + 1;
        amount1 = (amount1 / 10) + 1;

        deal(USDC, secondDepositor, amount0);
        deal(WETH, secondDepositor, amount1);

        vm.startPrank(secondDepositor);
        IERC20Metadata(USDC).approve(address(module), amount0);
        IERC20Metadata(WETH).approve(address(module), amount1);
        vm.stopPrank();

        vm.prank(metaVault);
        module.deposit(secondDepositor, BASE / 10);

        // #endregion second deposit.
    }

    function testDepositActiveRangeAndSwap() public {
        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));

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

        // #region do swap.

        poolManager.unlock(abi.encode(1));

        // #endregion do swap.

        // #region second deposit.

        address secondDepositor =
            vm.addr(uint256(keccak256(abi.encode("Second deposit"))));

        (uint256 amount0, uint256 amount1) = module.totalUnderlying();

        amount0 = amount0 + 1;
        amount1 = amount1 + 1;

        deal(USDC, secondDepositor, amount0);
        deal(WETH, secondDepositor, amount1);

        vm.startPrank(secondDepositor);
        IERC20Metadata(USDC).approve(address(module), amount0);
        IERC20Metadata(WETH).approve(address(module), amount1);
        vm.stopPrank();

        vm.prank(metaVault);
        module.deposit(secondDepositor, BASE);

        // #endregion second deposit.
    }

    function testDepositActiveRangeAndSwapBis() public {
        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));

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

        // #region do swap.

        poolManager.unlock(abi.encode(3));

        // #endregion do swap.

        // #region second deposit.

        address secondDepositor =
            vm.addr(uint256(keccak256(abi.encode("Second deposit"))));

        (uint256 amount0, uint256 amount1) = module.totalUnderlying();

        amount0 = amount0 + 1;
        amount1 = amount1 + 1;

        deal(USDC, secondDepositor, amount0);
        deal(WETH, secondDepositor, amount1);

        vm.startPrank(secondDepositor);
        IERC20Metadata(USDC).approve(address(module), amount0);
        IERC20Metadata(WETH).approve(address(module), amount1);
        vm.stopPrank();

        vm.prank(metaVault);
        module.deposit(secondDepositor, BASE);

        // #endregion second deposit.
    }

    function testDepositActiveRangeAndSwapBothSide() public {
        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));

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

        // #region do swap.

        poolManager.unlock(abi.encode(1));
        poolManager.unlock(abi.encode(3));

        // #endregion do swap.

        // #region second deposit.

        address secondDepositor =
            vm.addr(uint256(keccak256(abi.encode("Second deposit"))));

        (uint256 amount0, uint256 amount1) = module.totalUnderlying();

        amount0 = amount0 + 1;
        amount1 = amount1 + 1;

        deal(USDC, secondDepositor, amount0);
        deal(WETH, secondDepositor, amount1);

        vm.startPrank(secondDepositor);
        IERC20Metadata(USDC).approve(address(module), amount0);
        IERC20Metadata(WETH).approve(address(module), amount1);
        vm.stopPrank();

        vm.prank(metaVault);
        module.deposit(secondDepositor, BASE);

        // #endregion second deposit.
    }

    function testDepositNative() public {
        Currency currency0 = CurrencyLibrary.ADDRESS_ZERO; // NATIVE COIN
        Currency currency1 = Currency.wrap(USDC);

        ArrakisMetaVaultMock(metaVault).setTokens(USDC, NATIVE_COIN);

        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 10_000,
            tickSpacing: 10,
            hooks: IHooks(address(0))
        });

        sqrtPriceX96 = 4_363_802_021_784_129_436_505_493;

        poolManager.unlock(abi.encode(2));

        // #region create uni v4 module.

        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        address implementation = address(
            new UniV4StandardModule(address(poolManager), guardian)
        );

        bytes memory data = abi.encodeWithSelector(
            IUniV4StandardModule.initialize.selector,
            init0,
            init1,
            true,
            poolKey,
            metaVault
        );

        module = UniV4StandardModule(
            payable(address(new ERC1967Proxy(implementation, data)))
        );

        vm.prank(address(manager));
        module.setManagerFeePIPS(10_000);

        // #endregion create uni v4 module.

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));

        deal(USDC, depositor, init0);
        deal(metaVault, init1);

        vm.startPrank(depositor);
        IERC20Metadata(USDC).approve(address(module), init0);
        vm.stopPrank();

        vm.prank(metaVault);
        module.deposit{value: 1 ether}(depositor, BASE);
    }

    function testDepositNativeActiveRange() public {
        Currency currency0 = CurrencyLibrary.ADDRESS_ZERO;
        Currency currency1 = Currency.wrap(USDC);

        ArrakisMetaVaultMock(metaVault).setTokens(USDC, NATIVE_COIN);

        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 10_000,
            tickSpacing: 10,
            hooks: IHooks(address(0))
        });

        sqrtPriceX96 = 4_363_802_021_784_129_436_505_493;

        poolManager.unlock(abi.encode(2));

        // #region create uni v4 module.

        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        address implementation = address(
            new UniV4StandardModule(address(poolManager), guardian)
        );

        bytes memory data = abi.encodeWithSelector(
            IUniV4StandardModule.initialize.selector,
            init0,
            init1,
            true,
            poolKey,
            metaVault
        );

        module = UniV4StandardModule(
            payable(address(new ERC1967Proxy(implementation, data)))
        );

        vm.prank(address(manager));
        module.setManagerFeePIPS(10_000);

        // #endregion create uni v4 module.

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));

        deal(USDC, depositor, init0);
        deal(metaVault, init1);

        vm.startPrank(depositor);
        IERC20Metadata(USDC).approve(address(module), init0);
        vm.stopPrank();

        vm.prank(metaVault);
        module.deposit{value: 1 ether}(depositor, BASE);

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
            init1,
            init0
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

        // #region second deposit.

        address secondDepositor =
            vm.addr(uint256(keccak256(abi.encode("Second deposit"))));

        (uint256 amount0, uint256 amount1) = module.totalUnderlying();

        amount0 = amount0 + 1;
        amount1 = amount1 + 1;

        deal(USDC, secondDepositor, amount0);
        deal(metaVault, amount1);

        vm.startPrank(secondDepositor);
        IERC20Metadata(USDC).approve(address(module), amount0);
        vm.stopPrank();

        vm.prank(metaVault);
        module.deposit{value: amount1}(secondDepositor, BASE);

        // #endregion second deposit.
    }

    function testDepositNativeOverSentEther() public {
        Currency currency0 = CurrencyLibrary.ADDRESS_ZERO;
        Currency currency1 = Currency.wrap(USDC);

        ArrakisMetaVaultMock(metaVault).setTokens(USDC, NATIVE_COIN);

        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 10_000,
            tickSpacing: 10,
            hooks: IHooks(address(0))
        });

        sqrtPriceX96 = 4_363_802_021_784_129_436_505_493;

        poolManager.unlock(abi.encode(2));

        // #region create uni v4 module.

        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        address implementation = address(
            new UniV4StandardModule(address(poolManager), guardian)
        );

        bytes memory data = abi.encodeWithSelector(
            IUniV4StandardModule.initialize.selector,
            init0,
            init1,
            true,
            poolKey,
            metaVault
        );

        module = UniV4StandardModule(
            payable(address(new ERC1967Proxy(implementation, data)))
        );

        vm.prank(address(manager));
        module.setManagerFeePIPS(10_000);

        // #endregion create uni v4 module.

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));

        deal(USDC, depositor, init0);
        deal(metaVault, 2 ether);

        vm.startPrank(depositor);
        IERC20Metadata(USDC).approve(address(module), init0);
        vm.stopPrank();

        vm.prank(metaVault);
        module.deposit{value: 2 ether}(depositor, BASE);
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

    function testWithdrawProportionGtBASE() public {
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

        vm.expectRevert(IArrakisLPModule.ProportionGtBASE.selector);

        vm.prank(metaVault);
        module.withdraw(receiver, BASE + 1);
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

    // #region test withdrawManagerBalance.

    function testWithdrawManagerBalance() public {
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

        vm.prank(manager);
        module.withdrawManagerBalance();
    }

    // #endregion test withdrawManagerBalance.

    // #region test setManagerFeePIPS.

    function testSetManagerFeePIPSOnlyManager() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisLPModule.OnlyManager.selector,
                address(this),
                manager
            )
        );

        uint256 newFeePIPS = PIPS / 500;

        module.setManagerFeePIPS(newFeePIPS);
    }

    function testSetManagerFeePIPSSameManagerFee() public {
        uint256 newFeePIPS = PIPS / 500;
        vm.prank(manager);
        module.setManagerFeePIPS(newFeePIPS);

        vm.expectRevert(IArrakisLPModule.SameManagerFee.selector);
        vm.prank(manager);
        module.setManagerFeePIPS(newFeePIPS);
    }

    function testSetManagerFeePIPSNewFeesGtPIPS() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisLPModule.NewFeesGtPIPS.selector, PIPS + 1
            )
        );
        vm.prank(manager);
        module.setManagerFeePIPS(PIPS + 1);
    }

    function testSetManagerFeePIPS() public {
        uint256 newFeePIPS = PIPS / 500;
        vm.prank(manager);
        module.setManagerFeePIPS(newFeePIPS);
    }

    // #endregion test setManagerFeePIPS.

    // #region test unlockCallback.

    function testUnlockCallbackOnlyPoolManager() public {
        vm.expectRevert(IUniV4StandardModule.OnlyPoolManager.selector);

        module.unlockCallback("");
    }

    function testUnlockCallbackCallBackNotSupported() public {
        vm.expectRevert(
            IUniV4StandardModule.CallBackNotSupported.selector
        );

        vm.prank(address(poolManager));
        module.unlockCallback(abi.encode(4, bytes("")));
    }

    // #endregion test unlockCallbask.

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

    function testRebalanceOverBurning() public {
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

        // #region do another rebalance to overburn.

        liquidityRange =
        IUniV4StandardModule.LiquidityRange({
            range: range,
            liquidity: -1 * SafeCast.toInt128(
                SafeCast.toInt256(uint256(liquidity + 10))
            )
        });

        liquidityRanges[0] = liquidityRange;

        vm.prank(manager);
        vm.expectRevert(IUniV4StandardModule.OverBurning.selector);
        module.rebalance(liquidityRanges);

        // #endregion do another rebalance to overburn.
    }

    function testRebalanceRangeShouldBeActive() public {
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

        // #region do a second rebalance to remove unknown liquidity.

        liquidityRange =
        IUniV4StandardModule.LiquidityRange({
            range: IUniV4StandardModule.Range({tickLower: tickLower + 50, tickUpper: tickUpper + 50}),
            liquidity: SafeCast.toInt128(
                -1 * SafeCast.toInt256(uint256(liquidity))
            )
        });

        liquidityRanges[0] = liquidityRange;

        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSelector(IUniV4StandardModule.RangeShouldBeActive.selector, tickLower + 50, tickUpper + 50));
        module.rebalance(liquidityRanges);

        // #endregion do a second rebalance to remove unknown liquidity.
    }

    function testRebalanceTicksMisordered() public {
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
            range: IUniV4StandardModule.Range({
                tickLower: tickUpper,
                tickUpper: tickLower
            }),
            liquidity: SafeCast.toInt128(
                SafeCast.toInt256(uint256(liquidity))
            )
        });

        IUniV4StandardModule.LiquidityRange[] memory liquidityRanges =
            new IUniV4StandardModule.LiquidityRange[](1);

        liquidityRanges[0] = liquidityRange;

        vm.prank(manager);
        vm.expectRevert(
            abi.encodeWithSelector(
                IUniV4StandardModule.TicksMisordered.selector,
                tickUpper,
                tickLower
            )
        );
        module.rebalance(liquidityRanges);

        // #endregion do rebalance.
    }

    function testRebalanceTickLowerOutOfBounds() public {
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
            range: IUniV4StandardModule.Range({
                tickLower: TickMath.MIN_TICK - 1,
                tickUpper: tickUpper
            }),
            liquidity: SafeCast.toInt128(
                SafeCast.toInt256(uint256(liquidity))
            )
        });

        IUniV4StandardModule.LiquidityRange[] memory liquidityRanges =
            new IUniV4StandardModule.LiquidityRange[](1);

        liquidityRanges[0] = liquidityRange;

        vm.prank(manager);
        vm.expectRevert(
            abi.encodeWithSelector(
                IUniV4StandardModule.TickLowerOutOfBounds.selector,
                TickMath.MIN_TICK - 1
            )
        );
        module.rebalance(liquidityRanges);

        // #endregion do rebalance.
    }

    function testRebalanceTickUpperOutOfBounds() public {
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
            range: IUniV4StandardModule.Range({
                tickLower: tickLower,
                tickUpper: TickMath.MAX_TICK + 1
            }),
            liquidity: SafeCast.toInt128(
                SafeCast.toInt256(uint256(liquidity))
            )
        });

        IUniV4StandardModule.LiquidityRange[] memory liquidityRanges =
            new IUniV4StandardModule.LiquidityRange[](1);

        liquidityRanges[0] = liquidityRange;

        vm.prank(manager);
        vm.expectRevert(
            abi.encodeWithSelector(
                IUniV4StandardModule.TickUpperOutOfBounds.selector,
                TickMath.MAX_TICK + 1
            )
        );
        module.rebalance(liquidityRanges);

        // #endregion do rebalance.
    }

    function testRebalanceSwapAndRebalance() public {
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

        // #region do swap 1 and 2.

        poolManager.unlock(abi.encode(1));
        poolManager.unlock(abi.encode(3));

        // #endregion do swap 1 and 2.

        // #region change ranges.

        tickLower = (tick / 10) * 10 - (5 * 10);
        tickUpper = (tick / 10) * 10 + (5 * 10);

        liquidityRanges = new IUniV4StandardModule.LiquidityRange[](2);

        liquidityRanges[0] = IUniV4StandardModule.LiquidityRange({
            range: range,
            liquidity: SafeCast.toInt128(
                -(SafeCast.toInt256(uint256(liquidity)))
            )
        });

        range = IUniV4StandardModule.Range({
            tickLower: tickLower,
            tickUpper: tickUpper
        });

        (uint256 amount0, uint256 amount1) = module.totalUnderlying();

        liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            amount0 / 2,
            amount1 / 2
        );

        liquidityRanges[1] = IUniV4StandardModule.LiquidityRange({
            range: range,
            liquidity: SafeCast.toInt128(
                (SafeCast.toInt256(uint256(liquidity)))
            )
        });

        vm.prank(manager);
        module.rebalance(liquidityRanges);

        // #endregion change ranges.

        // #region withdraw.

        vm.prank(metaVault);
        module.withdraw(receiver, BASE);

        assertEq(
            IERC20Metadata(USDC).balanceOf(receiver), amount0 - 1
        );
        assertEq(
            IERC20Metadata(WETH).balanceOf(receiver), amount1 - 1
        );

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

    function testValidateRebalanceSqrtPriceX96OverMaxUint128()
        public
    {
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

        address implementation = address(
            new UniV4StandardModule(address(poolManager), guardian)
        );

        bytes memory data = abi.encodeWithSelector(
            IUniV4StandardModule.initialize.selector,
            init0,
            init1,
            false,
            poolKey,
            metaVault
        );

        module = UniV4StandardModule(
            payable(address(new ERC1967Proxy(implementation, data)))
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

        oraclePrice = FullMath.mulDiv(oraclePrice, 101, 100);

        OracleMock oracle = new OracleMock();

        oracle.setPrice0(oraclePrice);

        uint24 maxDeviation = 10_010;

        module.validateRebalance(
            IOracleWrapper(address(oracle)), maxDeviation
        );

        // #endregion compute oracle price.
    }

    // #endregion test validateRebalance.

    // #region internal functions.

    function _lockAcquiredSwap() internal {
        IPoolManager.SwapParams memory params = IPoolManager
            .SwapParams({
            zeroForOne: false,
            amountSpecified: 1_000_774_893,
            sqrtPriceLimitX96: TickMath.MAX_SQRT_PRICE / 2
        });
        poolManager.swap(poolKey, params, "");

        // #region settle currency.

        int256 currency0BalanceRaw = IPoolManager(
            address(poolManager)
        ).currencyDelta(address(this), poolKey.currency0);

        uint256 currency0Balance =
            SafeCast.toUint256(currency0BalanceRaw);

        int256 currency1BalanceRaw = IPoolManager(
            address(poolManager)
        ).currencyDelta(address(this), poolKey.currency1);

        uint256 currency1Balance =
            SafeCast.toUint256(-currency1BalanceRaw);

        if (currency0Balance > 0) {
            poolManager.take(
                poolKey.currency0, address(this), currency0Balance
            );
        }

        if (currency1Balance > 0) {
            poolManager.sync(poolKey.currency1);
            deal(WETH, address(this), currency1Balance);
            IERC20Metadata(WETH).transfer(
                address(poolManager), currency1Balance
            );
            poolManager.settle();
        }

        // #endregion settle currency.
    }

    function _lockAcquiredSwapBis() internal {
        IPoolManager.SwapParams memory params = IPoolManager
            .SwapParams({
            zeroForOne: true,
            amountSpecified: (1 ether) / 1000,
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE * 2
        });
        poolManager.swap(poolKey, params, "");

        // #region settle currency.

        int256 currency0BalanceRaw = IPoolManager(
            address(poolManager)
        ).currencyDelta(address(this), poolKey.currency0);

        uint256 currency0Balance =
            SafeCast.toUint256(-currency0BalanceRaw);

        int256 currency1BalanceRaw = IPoolManager(
            address(poolManager)
        ).currencyDelta(address(this), poolKey.currency1);

        uint256 currency1Balance =
            SafeCast.toUint256(currency1BalanceRaw);

        if (currency1Balance > 0) {
            poolManager.take(
                poolKey.currency1, address(this), currency1Balance
            );
        }

        if (currency0Balance > 0) {
            poolManager.sync(poolKey.currency0);
            deal(USDC, address(this), currency0Balance);
            IERC20Metadata(USDC).transfer(
                address(poolManager), currency0Balance
            );
            poolManager.settle();
        }

        // #endregion settle currency.
    }

    // #endregion internal functions.
}
