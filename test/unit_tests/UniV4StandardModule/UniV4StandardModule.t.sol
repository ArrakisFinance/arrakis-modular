// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// #region foundry.
import {console} from "forge-std/console.sol";
import {TestWrapper} from "../../utils/TestWrapper.sol";
// #endregion foundry.

// #region Uniswap Module.
import {UniV4StandardModulePublic} from
    "../../../src/modules/UniV4StandardModulePublic.sol";
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
    TEN_PERCENT,
    NATIVE_COIN
} from "../../../src/constants/CArrakis.sol";
import {SwapPayload} from "../../../src/structs/SUniswapV4.sol";
import {EthFlowData, Data, SignatureData} from "../../../src/structs/SCowswap.sol";
import {IERC20} from "../../../src/interfaces/ICowSwapERC20.sol";
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

// #region utils.

import {OrderLib} from "../../utils/OrderLib.sol";

// #endregion utils.

interface IERC20USDT {
    function transfer(address _to, uint256 _value) external;
    function approve(address spender, uint256 value) external;
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external;
}

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
    address public constant COW_SWAP_ETH_FLOW =
        0x40A50cf069e992AA4536211B23F286eF88752187;
    bytes32 public constant DOMAIN_SEPARATOR =
        0xc078f884a2676e1345748b1feace7b0abee5d00ecadb6e574dcdd109a63e8943;

    // #endregion constants.

    PoolManager public poolManager;
    PoolKey public poolKey;
    uint160 public sqrtPriceX96;
    address public manager;
    address public pauser;
    address public metaVault;
    address public guardian;
    address public owner;

    // #region mocks contracts.

    OracleMock public oracle;

    // #endregion mocks contracts.

    UniV4StandardModulePublic public module;

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

        // #region create an oracle.

        oracle = new OracleMock();

        // #endregion create an oracle.

        // #endregion do a poolManager deployment.

        // #region create uni v4 module.

        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        address implementation = address(
            new UniV4StandardModulePublic(
                address(poolManager), guardian, COW_SWAP_ETH_FLOW
            )
        );

        bytes memory data = abi.encodeWithSelector(
            IUniV4StandardModule.initialize.selector,
            init0,
            init1,
            false,
            poolKey,
            IOracleWrapper(address(oracle)),
            TEN_PERCENT,
            metaVault
        );

        module = UniV4StandardModulePublic(
            payable(address(new ERC1967Proxy(implementation, data)))
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

        if (typeOfLockAcquired == 4) {
            // Native coin.
            _lockAcquiredSwapNative();
        }

        if (typeOfLockAcquired == 5) {
            _lockAcquiredSwapWETHUSDT();
        }

        if (typeOfLockAcquired == 6) {
            _lockAcquiredSwapETHUSDT();
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
        new UniV4StandardModulePublic(
            address(0), guardian, COW_SWAP_ETH_FLOW
        );
    }

    function testConstructorMetaVaultAddressZero() public {
        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        address implmentation = address(
            new UniV4StandardModulePublic(
                address(poolManager), guardian, COW_SWAP_ETH_FLOW
            )
        );

        bytes memory data = abi.encodeWithSelector(
            IUniV4StandardModule.initialize.selector,
            init0,
            init1,
            false,
            poolKey,
            IOracleWrapper(address(oracle)),
            TEN_PERCENT,
            address(0)
        );

        vm.expectRevert(IArrakisLPModule.AddressZero.selector);
        module = UniV4StandardModulePublic(
            payable(address(new ERC1967Proxy(implmentation, data)))
        );
    }

    function testConstructorGuardianAddressZero() public {
        vm.expectRevert(IArrakisLPModule.AddressZero.selector);
        new UniV4StandardModulePublic(
            address(poolManager), address(0), COW_SWAP_ETH_FLOW
        );
    }

    function testConstructorCowSwapEthFlowAddressZero() public {
        vm.expectRevert(IArrakisLPModule.AddressZero.selector);
        new UniV4StandardModulePublic(
            address(poolManager), guardian, address(0)
        );
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
            new UniV4StandardModulePublic(
                address(poolManager), guardian, COW_SWAP_ETH_FLOW
            )
        );

        bytes memory data = abi.encodeWithSelector(
            IUniV4StandardModule.initialize.selector,
            init0,
            init1,
            false,
            poolKey,
            IOracleWrapper(address(oracle)),
            TEN_PERCENT,
            metaVault
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IUniV4StandardModule.Currency0DtToken0.selector,
                WETH,
                USDC
            )
        );
        module = UniV4StandardModulePublic(
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
            new UniV4StandardModulePublic(
                address(poolManager), guardian, COW_SWAP_ETH_FLOW
            )
        );

        bytes memory data = abi.encodeWithSelector(
            IUniV4StandardModule.initialize.selector,
            init0,
            init1,
            false,
            poolKey,
            IOracleWrapper(address(oracle)),
            TEN_PERCENT,
            metaVault
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IUniV4StandardModule.Currency0DtToken0.selector,
                WETH,
                NATIVE_COIN
            )
        );
        module = UniV4StandardModulePublic(
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
            new UniV4StandardModulePublic(
                address(poolManager), guardian, COW_SWAP_ETH_FLOW
            )
        );

        bytes memory data = abi.encodeWithSelector(
            IUniV4StandardModule.initialize.selector,
            init0,
            init1,
            false,
            poolKey,
            IOracleWrapper(address(oracle)),
            TEN_PERCENT,
            metaVault
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IUniV4StandardModule.Currency1DtToken1.selector,
                USDT,
                WETH
            )
        );
        module = UniV4StandardModulePublic(
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
            new UniV4StandardModulePublic(
                address(poolManager), guardian, COW_SWAP_ETH_FLOW
            )
        );

        bytes memory data = abi.encodeWithSelector(
            IUniV4StandardModule.initialize.selector,
            init0,
            init1,
            true,
            poolKey,
            IOracleWrapper(address(oracle)),
            TEN_PERCENT,
            metaVault
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IUniV4StandardModule.Currency1DtToken0.selector,
                USDT,
                USDC
            )
        );
        module = UniV4StandardModulePublic(
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
            new UniV4StandardModulePublic(
                address(poolManager), guardian, COW_SWAP_ETH_FLOW
            )
        );

        bytes memory data = abi.encodeWithSelector(
            IUniV4StandardModule.initialize.selector,
            init0,
            init1,
            true,
            poolKey,
            IOracleWrapper(address(oracle)),
            TEN_PERCENT,
            metaVault
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IUniV4StandardModule.Currency0DtToken1.selector,
                address(1),
                NATIVE_COIN
            )
        );
        module = UniV4StandardModulePublic(
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
            new UniV4StandardModulePublic(
                address(poolManager), guardian, COW_SWAP_ETH_FLOW
            )
        );

        bytes memory data = abi.encodeWithSelector(
            IUniV4StandardModule.initialize.selector,
            init0,
            init1,
            true,
            poolKey,
            IOracleWrapper(address(oracle)),
            TEN_PERCENT,
            metaVault
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IUniV4StandardModule.Currency0DtToken1.selector,
                address(1),
                WETH
            )
        );
        module = UniV4StandardModulePublic(
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
            new UniV4StandardModulePublic(
                address(poolManager), guardian, COW_SWAP_ETH_FLOW
            )
        );

        bytes memory data = abi.encodeWithSelector(
            IUniV4StandardModule.initialize.selector,
            init0,
            init1,
            true,
            poolKey,
            IOracleWrapper(address(oracle)),
            TEN_PERCENT,
            metaVault
        );

        vm.expectRevert(
            IUniV4StandardModule.NativeCoinCannotBeToken1.selector
        );
        module = UniV4StandardModulePublic(
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
            new UniV4StandardModulePublic(
                address(poolManager), guardian, COW_SWAP_ETH_FLOW
            )
        );

        bytes memory data = abi.encodeWithSelector(
            IUniV4StandardModule.initialize.selector,
            init0,
            init1,
            false,
            poolKey,
            IOracleWrapper(address(oracle)),
            TEN_PERCENT,
            metaVault
        );

        vm.expectRevert(
            IUniV4StandardModule.NativeCoinCannotBeToken1.selector
        );
        module = UniV4StandardModulePublic(
            payable(address(new ERC1967Proxy(implmentation, data)))
        );
    }

    function testConstructorNoRemoveLiquidityHooksBefore() public {
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
            new UniV4StandardModulePublic(
                address(poolManager), guardian, COW_SWAP_ETH_FLOW
            )
        );

        bytes memory data = abi.encodeWithSelector(
            IUniV4StandardModule.initialize.selector,
            init0,
            init1,
            false,
            poolKey,
            IOracleWrapper(address(oracle)),
            TEN_PERCENT,
            metaVault
        );

        vm.expectRevert(
            IUniV4StandardModule.NoRemoveOrAddLiquidityHooks.selector
        );
        module = UniV4StandardModulePublic(
            payable(address(new ERC1967Proxy(implmentation, data)))
        );
    }

    function testConstructorNoRemoveLiquidityHooksAfter() public {
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
            new UniV4StandardModulePublic(
                address(poolManager), guardian, COW_SWAP_ETH_FLOW
            )
        );

        bytes memory data = abi.encodeWithSelector(
            IUniV4StandardModule.initialize.selector,
            init0,
            init1,
            false,
            poolKey,
            IOracleWrapper(address(oracle)),
            TEN_PERCENT,
            metaVault
        );

        vm.expectRevert(
            IUniV4StandardModule.NoRemoveOrAddLiquidityHooks.selector
        );
        module = UniV4StandardModulePublic(
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
            new UniV4StandardModulePublic(
                address(poolManager), guardian, COW_SWAP_ETH_FLOW
            )
        );

        bytes memory data = abi.encodeWithSelector(
            IUniV4StandardModule.initialize.selector,
            init0,
            init1,
            false,
            poolKey,
            IOracleWrapper(address(oracle)),
            TEN_PERCENT,
            metaVault
        );

        vm.expectRevert(IUniV4StandardModule.SqrtPriceZero.selector);
        module = UniV4StandardModulePublic(
            payable(address(new ERC1967Proxy(implmentation, data)))
        );
    }

    function testConstructorMaxSlippageGtTenPercent() public {
        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        poolKey.tickSpacing = 20;

        poolManager.unlock(abi.encode(2));

        address implmentation = address(
            new UniV4StandardModulePublic(
                address(poolManager), guardian, COW_SWAP_ETH_FLOW
            )
        );

        bytes memory data = abi.encodeWithSelector(
            IUniV4StandardModule.initialize.selector,
            init0,
            init1,
            true,
            poolKey,
            IOracleWrapper(address(oracle)),
            TEN_PERCENT + 1,
            metaVault
        );

        vm.expectRevert(
            IUniV4StandardModule.MaxSlippageGtTenPercent.selector
        );
        module = UniV4StandardModulePublic(
            payable(address(new ERC1967Proxy(implmentation, data)))
        );
    }

    // #endregion test constructor.

    // #region test initializePosition.

    function testInitializePositionOnlyMetaVault() public {
        address notMetaVault =
            vm.addr(uint256(keccak256(abi.encode("NotMetaVault"))));

        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisLPModule.OnlyMetaVault.selector,
                notMetaVault,
                address(metaVault)
            )
        );
        vm.prank(notMetaVault);

        module.initializePosition("");
    }

    function testInitializePosition() public {
        deal(USDC, address(module), 3000e6);
        deal(WETH, address(module), 1e18);

        vm.prank(metaVault);
        module.initializePosition("");
    }

    function testInitializePositionNativeCoin() public {
        Currency currency0 = Currency.wrap(address(0));
        Currency currency1 = Currency.wrap(USDC);

        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 10_000,
            tickSpacing: 10,
            hooks: IHooks(address(0))
        });

        sqrtPriceX96 = 1_356_476_084_642_877_807_665_053_548_195_417;

        poolManager.unlock(abi.encode(2));

        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        address implementation = address(
            new UniV4StandardModulePublic(
                address(poolManager), guardian, COW_SWAP_ETH_FLOW
            )
        );

        bytes memory data = abi.encodeWithSelector(
            IUniV4StandardModule.initialize.selector,
            init0,
            init1,
            true,
            poolKey,
            IOracleWrapper(address(oracle)),
            TEN_PERCENT,
            metaVault
        );

        ArrakisMetaVaultMock(metaVault).setTokens(USDC, NATIVE_COIN);

        module = UniV4StandardModulePublic(
            payable(address(new ERC1967Proxy(implementation, data)))
        );

        deal(USDC, address(module), 3000e6);
        deal(address(module), 1e18);

        vm.prank(metaVault);
        module.initializePosition("");
    }

    // #endregion test initializePosition.

    // #region test approve.

    function testApproveOnlyMetaVaultOwner() public {
        address notMetaVaultOwner = vm.addr(
            uint256(keccak256(abi.encode("notMetaVaultOwner")))
        );

        address spender =
            vm.addr(uint256(keccak256(abi.encode("Spender"))));

        vm.expectRevert(
            IUniV4StandardModule.OnlyMetaVaultOwner.selector
        );
        vm.prank(notMetaVaultOwner);
        module.approve(spender, 3000e6, 1e18);
    }

    function testApprove() public {
        address spender =
            vm.addr(uint256(keccak256(abi.encode("Spender"))));

        vm.prank(owner);
        module.approve(spender, 3000e6, 1e18);

        assertEq(
            IERC20Metadata(USDC).allowance(address(module), spender),
            3000e6
        );
        assertEq(
            IERC20Metadata(WETH).allowance(address(module), spender),
            1e18
        );
    }

    // #endregion test approve.

    // #region create eth flow order.

    function testCreateEthFlowOrderOnlyManager() public {
        address notManager = vm.addr(
            uint256(keccak256(abi.encode("NotManager")))
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisLPModule.OnlyManager.selector,
                notManager,
                manager
            )
        );

        vm.prank(notManager);
        module.createEthFlowOrder(EthFlowData({
            buyToken: IERC20(USDC),
            receiver: address(module),
            sellAmount: 1 ether,
            buyAmount: 1645_000_000,
            appData: bytes32(0),
            feeAmount: 0,
            validTo: type(uint32).max,
            partiallyFillable: false,
            quoteId: 0
        }));
    }

    function testCreateEthFlowOrderInvalidReceiver() public {
        vm.expectRevert(
            IUniV4StandardModule.InvalidReceiver.selector
        );

        vm.prank(manager);
        module.createEthFlowOrder(EthFlowData({
            buyToken: IERC20(USDC),
            receiver: address(this),
            sellAmount: 1 ether,
            buyAmount: 1645_000_000,
            appData: bytes32(0),
            feeAmount: 0,
            validTo: type(uint32).max,
            partiallyFillable: false,
            quoteId: 0
        }));
    }

    function testCreateEthFlowOrderInvalidTokens() public {
        deal(address(module), 1.1 ether);

        vm.prank(manager);
        vm.expectRevert(IUniV4StandardModule.InvalidTokens.selector);
        module.createEthFlowOrder(EthFlowData({
            buyToken: IERC20(USDC),
            receiver: address(module),
            sellAmount: 1 ether,
            buyAmount: 1645_000_000,
            appData: bytes32(0),
            feeAmount: 0.1 ether,
            validTo: type(uint32).max,
            partiallyFillable: false,
            quoteId: 0
        }));
    }

    function testCreateEthFlowOrder() public {
        Currency currency0 = Currency.wrap(address(0));
        Currency currency1 = Currency.wrap(USDC);

        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 10_000,
            tickSpacing: 10,
            hooks: IHooks(address(0))
        });

        sqrtPriceX96 = 1_356_476_084_642_877_807_665_053_548_195_417;

        poolManager.unlock(abi.encode(2));

        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        address implementation = address(
            new UniV4StandardModulePublic(
                address(poolManager), guardian, COW_SWAP_ETH_FLOW
            )
        );

        bytes memory data = abi.encodeWithSelector(
            IUniV4StandardModule.initialize.selector,
            init0,
            init1,
            true,
            poolKey,
            IOracleWrapper(address(oracle)),
            TEN_PERCENT,
            metaVault
        );

        ArrakisMetaVaultMock(metaVault).setTokens(USDC, NATIVE_COIN);

        module = UniV4StandardModulePublic(
            payable(address(new ERC1967Proxy(implementation, data)))
        );

        deal(address(module), 1.1 ether);

        vm.prank(manager);
        module.createEthFlowOrder(EthFlowData({
            buyToken: IERC20(USDC),
            receiver: address(module),
            sellAmount: 1 ether,
            buyAmount: 1645_000_000,
            appData: bytes32(0),
            feeAmount: 0.1 ether,
            validTo: type(uint32).max,
            partiallyFillable: false,
            quoteId: 0
        }));
    }

    // #endregion create eth flow order.

    // #region invalidate eth flow order.

    function testInvalidateEthFlowOrderOnlyManager() public {
        address notManager = vm.addr(
            uint256(keccak256(abi.encode("NotManager")))
        );

        EthFlowData memory data = EthFlowData({
            buyToken: IERC20(USDC),
            receiver: address(module),
            sellAmount: 1 ether,
            buyAmount: 1645_000_000,
            appData: bytes32(0),
            feeAmount: 0.1 ether,
            validTo: type(uint32).max,
            partiallyFillable: false,
            quoteId: 0
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisLPModule.OnlyManager.selector,
                notManager,
                manager
            )
        );

        vm.prank(notManager);
        module.invalidateEthFlowOrder(data);
    }

    function testInvalidateEthFlowOrder() public {
        // #region create eth flow order.

        Currency currency0 = Currency.wrap(address(0));
        Currency currency1 = Currency.wrap(USDC);

        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 10_000,
            tickSpacing: 10,
            hooks: IHooks(address(0))
        });

        sqrtPriceX96 = 1_356_476_084_642_877_807_665_053_548_195_417;

        poolManager.unlock(abi.encode(2));

        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        address implementation = address(
            new UniV4StandardModulePublic(
                address(poolManager), guardian, COW_SWAP_ETH_FLOW
            )
        );

        bytes memory data = abi.encodeWithSelector(
            IUniV4StandardModule.initialize.selector,
            init0,
            init1,
            true,
            poolKey,
            IOracleWrapper(address(oracle)),
            TEN_PERCENT,
            metaVault
        );

        ArrakisMetaVaultMock(metaVault).setTokens(USDC, NATIVE_COIN);

        module = UniV4StandardModulePublic(
            payable(address(new ERC1967Proxy(implementation, data)))
        );

        EthFlowData memory ethFlowData = EthFlowData({
            buyToken: IERC20(USDC),
            receiver: address(module),
            sellAmount: 1 ether,
            buyAmount: 1645_000_000,
            appData: bytes32(0),
            feeAmount: 0.1 ether,
            validTo: type(uint32).max,
            partiallyFillable: false,
            quoteId: 0
        });

        deal(address(module), 1.1 ether);

        vm.prank(manager);
        module.createEthFlowOrder(ethFlowData);

        // #endregion create eth flow order.

        vm.prank(manager);
        module.invalidateEthFlowOrder(ethFlowData);
    }

    // #endregion invalidate eth flow order.

    // #region test setCowSwapSigner.

    function testSetCowSwapSignerOnlyManager() public {
        address notManager = vm.addr(
            uint256(keccak256(abi.encode("NotManager")))
        );

        (address signerAddr, ) = makeAddrAndKey("Signer");

        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisLPModule.OnlyManager.selector,
                notManager,
                manager
            )
        );

        vm.prank(notManager);
        module.setCowSwapSigner(signerAddr);
    }

    function testSetCowSwapSignerAddresZero() public {
        vm.expectRevert(
            IArrakisLPModule.AddressZero.selector
        );

        vm.prank(manager);
        module.setCowSwapSigner(address(0));
    }

    function testSetCowSwapSignerSame() public {
        (address signerAddr, ) = makeAddrAndKey("Signer");

        vm.prank(manager);
        module.setCowSwapSigner(signerAddr);

        vm.expectRevert(
            IUniV4StandardModule.SameCowSwapSigner.selector
        );

        vm.prank(manager);
        module.setCowSwapSigner(signerAddr);
    }

    function testSetCowSwapSigner() public {
        (address signerAddr, ) = makeAddrAndKey("Signer");

        vm.prank(manager);
        module.setCowSwapSigner(signerAddr);
    }

    // #endregion test setCowSwapSigner.

    // #region test isValidSignature.

    function testIsValidSignatureInvalidOrderHash() public {
        uint256 amount0 = 1645e6;
        uint256 amount1 = 1e18;

        // #region set cowSwapSigner.

        uint256 signerKey = 123;

        address signerAddr = vm.addr(signerKey);

        vm.prank(manager);
        module.setCowSwapSigner(signerAddr);

        // #endregion set cowSwapSigner.

        Data memory orderData = Data({
            sellToken: IERC20(USDC),
            buyToken: IERC20(WETH),
            receiver: address(module),
            sellAmount: amount0/10,
            buyAmount: amount1/10,
            validTo: type(uint32).max,
            appData: bytes32(0),
            feeAmount: 0,
            kind: bytes32(0),
            partiallyFillable: false,
            sellTokenBalance: OrderLib.BALANCE_ERC20,
            buyTokenBalance: OrderLib.BALANCE_ERC20
        });

        bytes32 orderHash = OrderLib.hash(orderData, DOMAIN_SEPARATOR);

        SignatureData memory signatureData = SignatureData({
            signedTimestamp: block.timestamp,
            nonce: 1,
            orderHash: orderHash,
            order: abi.encode(orderData),
            signature: ""
        });

        bytes memory signature = getEOASignedOrder(orderData, signerKey, address(module), signatureData.signedTimestamp, signatureData.nonce, signatureData.orderHash);

        signatureData.signature = signature;

        bytes memory signData = abi.encode(signatureData);

        orderData.sellAmount -= 1;
        orderHash = OrderLib.hash(orderData, DOMAIN_SEPARATOR);

        vm.expectRevert(
            IUniV4StandardModule.InvalidOrderHash.selector
        );
        module.isValidSignature(orderHash, signData);
    }

    function testIsValidSignatureInvalidOrder() public {
        uint256 amount0 = 1645e6;
        uint256 amount1 = 1e18;

        // #region set cowSwapSigner.

        uint256 signerKey = 123;

        address signerAddr = vm.addr(signerKey);

        vm.prank(manager);
        module.setCowSwapSigner(signerAddr);

        // #endregion set cowSwapSigner.

        Data memory orderData = Data({
            sellToken: IERC20(USDC),
            buyToken: IERC20(WETH),
            receiver: address(module),
            sellAmount: amount0/10,
            buyAmount: amount1/10,
            validTo: uint32(block.timestamp - 3600),
            appData: bytes32(0),
            feeAmount: 0,
            kind: bytes32(0),
            partiallyFillable: false,
            sellTokenBalance: OrderLib.BALANCE_ERC20,
            buyTokenBalance: OrderLib.BALANCE_ERC20
        });

        bytes32 orderHash = OrderLib.hash(orderData, DOMAIN_SEPARATOR);

        SignatureData memory signatureData = SignatureData({
            signedTimestamp: uint32(block.timestamp - 7200),
            nonce: 1,
            orderHash: orderHash,
            order: abi.encode(orderData),
            signature: ""
        });

        bytes memory signature = getEOASignedOrder(orderData, signerKey, address(module), signatureData.signedTimestamp, signatureData.nonce, signatureData.orderHash);

        signatureData.signature = signature;

        bytes memory signData = abi.encode(signatureData);

        vm.expectRevert(
            IUniV4StandardModule.InvalidOrder.selector
        );
        module.isValidSignature(orderHash, signData);
    }

    function testIsValidSignatureInvalidReceiver() public {
        uint256 amount0 = 1645e6;
        uint256 amount1 = 1e18;

        // #region set cowSwapSigner.

        uint256 signerKey = 123;

        address signerAddr = vm.addr(signerKey);

        vm.prank(manager);
        module.setCowSwapSigner(signerAddr);

        // #endregion set cowSwapSigner.

        Data memory orderData = Data({
            sellToken: IERC20(USDC),
            buyToken: IERC20(WETH),
            receiver: address(0),
            sellAmount: amount0/10,
            buyAmount: amount1/10,
            validTo: type(uint32).max,
            appData: bytes32(0),
            feeAmount: 0,
            kind: bytes32(0),
            partiallyFillable: false,
            sellTokenBalance: OrderLib.BALANCE_ERC20,
            buyTokenBalance: OrderLib.BALANCE_ERC20
        });

        bytes32 orderHash = OrderLib.hash(orderData, DOMAIN_SEPARATOR);

        SignatureData memory signatureData = SignatureData({
            signedTimestamp: block.timestamp,
            nonce: 1,
            orderHash: orderHash,
            order: abi.encode(orderData),
            signature: ""
        });

        bytes memory signature = getEOASignedOrder(orderData, signerKey, address(module), signatureData.signedTimestamp, signatureData.nonce, signatureData.orderHash);

        signatureData.signature = signature;

        bytes memory signData = abi.encode(signatureData);

        vm.expectRevert(
            IUniV4StandardModule.InvalidReceiver.selector
        );
        module.isValidSignature(orderHash, signData);
    }

    function testIsValidSignatureInvalidSignature() public {
        uint256 amount0 = 1645e6;
        uint256 amount1 = 1e18;

        // #region set cowSwapSigner.

        uint256 signerKey = 123;

        address signerAddr = vm.addr(signerKey);

        vm.prank(manager);
        module.setCowSwapSigner(signerAddr);

        // #endregion set cowSwapSigner.

        Data memory orderData = Data({
            sellToken: IERC20(USDC),
            buyToken: IERC20(WETH),
            receiver: address(module),
            sellAmount: amount0/10,
            buyAmount: amount1/10,
            validTo: type(uint32).max,
            appData: bytes32(0),
            feeAmount: 0,
            kind: bytes32(0),
            partiallyFillable: false,
            sellTokenBalance: OrderLib.BALANCE_ERC20,
            buyTokenBalance: OrderLib.BALANCE_ERC20
        });

        bytes32 orderHash = OrderLib.hash(orderData, DOMAIN_SEPARATOR);

        SignatureData memory signatureData = SignatureData({
            signedTimestamp: block.timestamp,
            nonce: 1,
            orderHash: orderHash,
            order: abi.encode(orderData),
            signature: ""
        });

        bytes memory signature = getEOASignedOrder(orderData, signerKey, address(module), signatureData.signedTimestamp, signatureData.nonce, signatureData.orderHash);

        signatureData.signature = signature;
        signatureData.signedTimestamp -= 1;

        bytes memory signData = abi.encode(signatureData);

        vm.expectRevert(
            IUniV4StandardModule.InvalidSignature.selector
        );
        module.isValidSignature(orderHash, signData);
    }

    function testIsValidSignature() public {
        uint256 amount0 = 1645e6;
        uint256 amount1 = 1e18;

        // #region set cowSwapSigner.

        uint256 signerKey = 123;

        address signerAddr = vm.addr(signerKey);

        vm.prank(manager);
        module.setCowSwapSigner(signerAddr);

        // #endregion set cowSwapSigner.

        Data memory orderData = Data({
            sellToken: IERC20(USDC),
            buyToken: IERC20(WETH),
            receiver: address(module),
            sellAmount: amount0/10,
            buyAmount: amount1/10,
            validTo: type(uint32).max,
            appData: bytes32(0),
            feeAmount: 0,
            kind: bytes32(0),
            partiallyFillable: false,
            sellTokenBalance: OrderLib.BALANCE_ERC20,
            buyTokenBalance: OrderLib.BALANCE_ERC20
        });

        bytes32 orderHash = OrderLib.hash(orderData, DOMAIN_SEPARATOR);

        SignatureData memory signatureData = SignatureData({
            signedTimestamp: block.timestamp,
            nonce: 1,
            orderHash: orderHash,
            order: abi.encode(orderData),
            signature: ""
        });

        bytes memory signature = getEOASignedOrder(orderData, signerKey, address(module), signatureData.signedTimestamp, signatureData.nonce, signatureData.orderHash);

        signatureData.signature = signature;

        bytes memory signData = abi.encode(signatureData);

        assertEq(
            module.isValidSignature(orderHash, signData),
            bytes4(0x1626ba7e)
        );
    }

    // #endregion test isValidSignature.

    // #region test set pool.

    function testSetPoolOnlyManager() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisLPModule.OnlyManager.selector,
                address(this),
                manager
            )
        );

        SwapPayload memory swapPayload;

        IUniV4StandardModule.LiquidityRange[] memory liquidityRange =
            new IUniV4StandardModule.LiquidityRange[](0);

        module.setPool(poolKey, liquidityRange, swapPayload);
    }

    function testSetPoolCurrency0DtToken0() public {
        address falseCurrency =
            vm.addr(uint256(keccak256(abi.encode("FalseCurrency"))));

        poolKey.currency0 = Currency.wrap(falseCurrency);

        SwapPayload memory swapPayload;

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
        module.setPool(poolKey, liquidityRange, swapPayload);
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

        SwapPayload memory swapPayload;

        vm.prank(manager);
        module.setPool(poolKey, liquidityRange, swapPayload);
    }

    function testSetPoolSamePool() public {
        IUniV4StandardModule.LiquidityRange[] memory liquidityRange =
            new IUniV4StandardModule.LiquidityRange[](0);

        SwapPayload memory swapPayload;
        vm.expectRevert(IUniV4StandardModule.SamePool.selector);

        vm.prank(manager);
        module.setPool(poolKey, liquidityRange, swapPayload);
    }

    function testSetPoolNoRemoveLiquidityHooks() public {
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

        SwapPayload memory swapPayload;

        vm.expectRevert(
            IUniV4StandardModule.NoRemoveOrAddLiquidityHooks.selector
        );
        vm.prank(manager);
        module.setPool(poolKey, liquidityRange, swapPayload);
    }

    function testSetPoolNoRemoveOrAddLiquidityHooks() public {
        SimpleHook hook = SimpleHook(
            address(uint160(Hooks.AFTER_ADD_LIQUIDITY_FLAG))
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

        SwapPayload memory swapPayload;

        vm.expectRevert(
            IUniV4StandardModule.NoRemoveOrAddLiquidityHooks.selector
        );
        vm.prank(manager);
        module.setPool(poolKey, liquidityRange, swapPayload);
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

        SwapPayload memory swapPayload;

        vm.expectRevert(IUniV4StandardModule.SqrtPriceZero.selector);
        vm.prank(manager);
        module.setPool(poolKey, liquidityRange, swapPayload);
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

        SwapPayload memory swapPayload;

        vm.prank(manager);
        module.setPool(poolKey, liquidityRange, swapPayload);
    }

    function testSetPoolWithRebalance() public {
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

        poolKey = PoolKey({
            currency0: Currency.wrap(USDC),
            currency1: Currency.wrap(WETH),
            fee: 3000,
            tickSpacing: 10,
            hooks: IHooks(address(0))
        });

        poolManager.unlock(abi.encode(2));

        // #region do rebalance payload.

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

        SwapPayload memory swapPayload;

        // #endregion do rebalance payload.

        vm.prank(manager);
        module.setPool(poolKey, liquidityRanges, swapPayload);
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

        SwapPayload memory swapPayload;

        vm.prank(manager);
        module.rebalance(liquidityRanges, swapPayload);

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
        module.setPool(poolKey, l, swapPayload);
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

    function testDepositAfterDonation() public {
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

        deal(USDC, address(module), 3000e6);
        deal(WETH, address(module), 1e18);

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

        SwapPayload memory swapPayload;

        vm.prank(manager);
        module.rebalance(liquidityRanges, swapPayload);

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

        SwapPayload memory swapPayload;

        vm.prank(manager);
        module.rebalance(liquidityRanges, swapPayload);

        // #endregion do rebalance.

        // #region second deposit.

        address secondDepositor =
            vm.addr(uint256(keccak256(abi.encode("Second deposit"))));

        (uint256 amount0, uint256 amount1) = module.totalUnderlying();

        amount0 = (amount0 / 2) + 1;
        amount1 = (amount1 / 2) + 1;

        deal(USDC, secondDepositor, amount0);
        deal(WETH, secondDepositor, amount1);

        vm.startPrank(secondDepositor);
        IERC20Metadata(USDC).approve(address(module), amount0);
        IERC20Metadata(WETH).approve(address(module), amount1);
        vm.stopPrank();

        vm.prank(metaVault);
        module.deposit(secondDepositor, BASE / 3);

        // #endregion second deposit.
    }

    function testDepositActiveRangeTooSmallMint() public {
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

        SwapPayload memory swapPayload;

        vm.prank(manager);
        module.rebalance(liquidityRanges, swapPayload);

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
        vm.expectRevert(
            IUniV4StandardModule.TooSmallMint.selector
        );
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

        SwapPayload memory swapPayload;

        vm.prank(manager);
        module.rebalance(liquidityRanges, swapPayload);

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

        SwapPayload memory swapPayload;

        vm.prank(manager);
        module.rebalance(liquidityRanges, swapPayload);

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

        SwapPayload memory swapPayload;

        vm.prank(manager);
        module.rebalance(liquidityRanges, swapPayload);

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
            new UniV4StandardModulePublic(
                address(poolManager), guardian, COW_SWAP_ETH_FLOW
            )
        );

        bytes memory data = abi.encodeWithSelector(
            IUniV4StandardModule.initialize.selector,
            init0,
            init1,
            true,
            poolKey,
            IOracleWrapper(address(oracle)),
            TEN_PERCENT,
            metaVault
        );

        module = UniV4StandardModulePublic(
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

    function testDepositNativeInvalidMsgValue() public {
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
            new UniV4StandardModulePublic(
                address(poolManager), guardian, COW_SWAP_ETH_FLOW
            )
        );

        bytes memory data = abi.encodeWithSelector(
            IUniV4StandardModule.initialize.selector,
            init0,
            init1,
            true,
            poolKey,
            IOracleWrapper(address(oracle)),
            TEN_PERCENT,
            metaVault
        );

        module = UniV4StandardModulePublic(
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
        vm.expectRevert(IUniV4StandardModule.InvalidMsgValue.selector);
        module.deposit{value: 0.5 ether}(depositor, BASE);
    }

    function testDepositNativeAfterDonation() public {
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
            new UniV4StandardModulePublic(
                address(poolManager), guardian, COW_SWAP_ETH_FLOW
            )
        );

        bytes memory data = abi.encodeWithSelector(
            IUniV4StandardModule.initialize.selector,
            init0,
            init1,
            true,
            poolKey,
            IOracleWrapper(address(oracle)),
            TEN_PERCENT,
            metaVault
        );

        module = UniV4StandardModulePublic(
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

        deal(address(module), 1e18);

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
            new UniV4StandardModulePublic(
                address(poolManager), guardian, COW_SWAP_ETH_FLOW
            )
        );

        bytes memory data = abi.encodeWithSelector(
            IUniV4StandardModule.initialize.selector,
            init0,
            init1,
            true,
            poolKey,
            IOracleWrapper(address(oracle)),
            TEN_PERCENT,
            metaVault
        );

        module = UniV4StandardModulePublic(
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

        SwapPayload memory swapPayload;

        vm.prank(manager);
        module.rebalance(liquidityRanges, swapPayload);

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
            new UniV4StandardModulePublic(
                address(poolManager), guardian, COW_SWAP_ETH_FLOW
            )
        );

        bytes memory data = abi.encodeWithSelector(
            IUniV4StandardModule.initialize.selector,
            init0,
            init1,
            true,
            poolKey,
            IOracleWrapper(address(oracle)),
            TEN_PERCENT,
            metaVault
        );

        module = UniV4StandardModulePublic(
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

    function testDepositNativeOverSentEtherAsToken0() public {
        Currency currency0 = CurrencyLibrary.ADDRESS_ZERO;
        Currency currency1 = Currency.wrap(USDC);

        ArrakisMetaVaultMock(metaVault).setTokens(NATIVE_COIN, USDC);

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

        uint256 init0 = 1e18;
        uint256 init1 = 3000e6;

        address implementation = address(
            new UniV4StandardModulePublic(
                address(poolManager), guardian, COW_SWAP_ETH_FLOW
            )
        );

        bytes memory data = abi.encodeWithSelector(
            IUniV4StandardModule.initialize.selector,
            init0,
            init1,
            false,
            poolKey,
            IOracleWrapper(address(oracle)),
            TEN_PERCENT,
            metaVault
        );

        module = UniV4StandardModulePublic(
            payable(address(new ERC1967Proxy(implementation, data)))
        );

        vm.prank(address(manager));
        module.setManagerFeePIPS(10_000);

        // #endregion create uni v4 module.

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));

        deal(metaVault, 2 ether);
        deal(USDC, depositor, init1);

        vm.startPrank(depositor);
        IERC20Metadata(USDC).approve(address(module), init1);
        vm.stopPrank();

        vm.prank(metaVault);
        module.deposit{value: 2 ether}(depositor, BASE);
    }

    function testDepositNativeUnderSentEtherAsToken0() public {
        Currency currency0 = CurrencyLibrary.ADDRESS_ZERO;
        Currency currency1 = Currency.wrap(USDC);

        ArrakisMetaVaultMock(metaVault).setTokens(NATIVE_COIN, USDC);

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

        uint256 init0 = 1e18;
        uint256 init1 = 3000e6;

        address implementation = address(
            new UniV4StandardModulePublic(
                address(poolManager), guardian, COW_SWAP_ETH_FLOW
            )
        );

        bytes memory data = abi.encodeWithSelector(
            IUniV4StandardModule.initialize.selector,
            init0,
            init1,
            false,
            poolKey,
            IOracleWrapper(address(oracle)),
            TEN_PERCENT,
            metaVault
        );

        module = UniV4StandardModulePublic(
            payable(address(new ERC1967Proxy(implementation, data)))
        );

        vm.prank(address(manager));
        module.setManagerFeePIPS(10_000);

        // #endregion create uni v4 module.

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));

        deal(metaVault, 2 ether);
        deal(USDC, depositor, init1);

        vm.startPrank(depositor);
        IERC20Metadata(USDC).approve(address(module), init1);
        vm.stopPrank();

        vm.prank(metaVault);
        vm.expectRevert(IUniV4StandardModule.InvalidMsgValue.selector);
        module.deposit{value: 0.5 ether}(depositor, BASE);
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

    function testWithdrawAfterSwap() public {
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

        SwapPayload memory swapPayload;

        vm.prank(manager);
        module.rebalance(liquidityRanges, swapPayload);

        // #endregion do rebalance.

        // #region do swap 1 and 2.

        poolManager.unlock(abi.encode(1));
        poolManager.unlock(abi.encode(3));

        // #endregion do swap 1 and 2.

        // #region withdraw.

        vm.prank(metaVault);
        module.withdraw(receiver, BASE / 2);

        // #endregion withdraw.
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

        SwapPayload memory swapPayload;

        vm.prank(manager);
        module.rebalance(liquidityRanges, swapPayload);

        // #endregion do rebalance.

        vm.prank(manager);
        module.withdrawManagerBalance();
    }

    function testWithdrawManagerBalanceWithSwap() public {
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

        SwapPayload memory swapPayload;

        vm.prank(manager);
        module.rebalance(liquidityRanges, swapPayload);

        // #endregion do rebalance.

        // #region do swap 1 and 2.

        poolManager.unlock(abi.encode(1));
        poolManager.unlock(abi.encode(3));

        // #endregion do swap 1 and 2.

        vm.prank(manager);
        module.withdrawManagerBalance();

        assertEq(
            IERC20Metadata(USDC).balanceOf(address(manager)), 344
        );
        assertEq(
            IERC20Metadata(WETH).balanceOf(address(manager)),
            29_641_691_633_406
        );
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
        vm.expectRevert();

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
        SwapPayload memory swapPayload;

        vm.prank(manager);
        module.rebalance(liquidityRanges, swapPayload);

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

        SwapPayload memory swapPayload;

        vm.prank(manager);
        module.rebalance(liquidityRanges, swapPayload);

        // #endregion do rebalance.

        // #region do another rebalance to overburn.

        liquidityRange = IUniV4StandardModule.LiquidityRange({
            range: range,
            liquidity: -1
                * SafeCast.toInt128(
                    SafeCast.toInt256(uint256(liquidity + 10))
                )
        });

        liquidityRanges[0] = liquidityRange;

        vm.prank(manager);
        vm.expectRevert(IUniV4StandardModule.OverBurning.selector);
        module.rebalance(liquidityRanges, swapPayload);

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

        SwapPayload memory swapPayload;

        vm.prank(manager);
        module.rebalance(liquidityRanges, swapPayload);

        // #endregion do rebalance.

        // #region do a second rebalance to remove unknown liquidity.

        liquidityRange = IUniV4StandardModule.LiquidityRange({
            range: IUniV4StandardModule.Range({
                tickLower: tickLower + 50,
                tickUpper: tickUpper + 50
            }),
            liquidity: SafeCast.toInt128(
                -1 * SafeCast.toInt256(uint256(liquidity))
            )
        });

        liquidityRanges[0] = liquidityRange;

        vm.prank(manager);
        vm.expectRevert(
            abi.encodeWithSelector(
                IUniV4StandardModule.RangeShouldBeActive.selector,
                tickLower + 50,
                tickUpper + 50
            )
        );
        module.rebalance(liquidityRanges, swapPayload);

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

        SwapPayload memory swapPayload;

        vm.prank(manager);
        vm.expectRevert(
            abi.encodeWithSelector(
                IUniV4StandardModule.TicksMisordered.selector,
                tickUpper,
                tickLower
            )
        );
        module.rebalance(liquidityRanges, swapPayload);

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

        SwapPayload memory swapPayload;

        vm.prank(manager);
        vm.expectRevert(
            abi.encodeWithSelector(
                IUniV4StandardModule.TickLowerOutOfBounds.selector,
                TickMath.MIN_TICK - 1
            )
        );
        module.rebalance(liquidityRanges, swapPayload);

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

        SwapPayload memory swapPayload;

        vm.prank(manager);
        vm.expectRevert(
            abi.encodeWithSelector(
                IUniV4StandardModule.TickUpperOutOfBounds.selector,
                TickMath.MAX_TICK + 1
            )
        );
        module.rebalance(liquidityRanges, swapPayload);

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

        SwapPayload memory swapPayload;

        vm.prank(manager);
        module.rebalance(liquidityRanges, swapPayload);

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
        module.rebalance(liquidityRanges, swapPayload);

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

    function testRebalanceSwapAndRebalanceWithSwapZeroForOne()
        public
    {
        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        Currency currency0 = Currency.wrap(USDC);
        Currency currency1 = Currency.wrap(WETH);

        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 10_000,
            tickSpacing: 20,
            hooks: IHooks(address(0))
        });

        sqrtPriceX96 = 1_546_089_921_970_950_693_041_566_601_029_373; // 2626,5 USDC/WETH.

        poolManager.unlock(abi.encode(2));

        {
            address implementation = address(
                new UniV4StandardModulePublic(
                    address(poolManager), guardian, COW_SWAP_ETH_FLOW
                )
            );

            bytes memory data = abi.encodeWithSelector(
                IUniV4StandardModule.initialize.selector,
                init0,
                init1,
                false,
                poolKey,
                IOracleWrapper(address(oracle)),
                TEN_PERCENT,
                metaVault
            );

            module = UniV4StandardModulePublic(
                payable(
                    address(new ERC1967Proxy(implementation, data))
                )
            );
        }

        vm.prank(address(manager));
        module.setManagerFeePIPS(10_000);

        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));
        {
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
        }

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

        SwapPayload memory swapPayload;

        vm.prank(manager);
        module.rebalance(liquidityRanges, swapPayload);

        // #endregion do rebalance.

        // #region do swap 1 and 2.

        poolManager.unlock(abi.encode(1));
        // poolManager.unlock(abi.encode(3));

        // #endregion do swap 1 and 2.

        // #region change ranges.

        tickLower = (tick / 10) * 10 - (5 * 10);
        tickUpper = (tick / 10) * 10 + (5 * 10);

        liquidityRanges = new IUniV4StandardModule.LiquidityRange[](1);

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

        swapPayload = SwapPayload({
            payload: abi.encodeWithSelector(this.swap.selector),
            router: address(this),
            amountIn: 0.25 ether,
            expectedMinReturn: 656_625_000,
            zeroForOne: false
        });

        vm.prank(manager);
        module.rebalance(liquidityRanges, swapPayload);

        // #endregion change ranges.

        // #region withdraw.

        (uint256 amount0, uint256 amount1) = module.totalUnderlying();

        vm.prank(metaVault);
        module.withdraw(receiver, BASE);

        assertEq(IERC20Metadata(USDC).balanceOf(receiver), amount0);
        assertEq(IERC20Metadata(WETH).balanceOf(receiver), amount1);

        // #endregion withdraw.
    }

    function testRebalanceSwapAndRebalanceWithSwapZeroForOneSlippageTooHigh(
    ) public {
        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        Currency currency0 = Currency.wrap(USDC);
        Currency currency1 = Currency.wrap(WETH);

        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 10_000,
            tickSpacing: 20,
            hooks: IHooks(address(0))
        });

        sqrtPriceX96 = 1_546_089_921_970_950_693_041_566_601_029_373; // 2626,5 USDC/WETH.

        poolManager.unlock(abi.encode(2));

        {
            address implementation = address(
                new UniV4StandardModulePublic(
                    address(poolManager), guardian, COW_SWAP_ETH_FLOW
                )
            );

            bytes memory data = abi.encodeWithSelector(
                IUniV4StandardModule.initialize.selector,
                init0,
                init1,
                false,
                poolKey,
                IOracleWrapper(address(oracle)),
                TEN_PERCENT,
                metaVault
            );

            module = UniV4StandardModulePublic(
                payable(
                    address(new ERC1967Proxy(implementation, data))
                )
            );
        }

        vm.prank(address(manager));
        module.setManagerFeePIPS(10_000);

        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));
        {
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
        }

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

        SwapPayload memory swapPayload;

        vm.prank(manager);
        module.rebalance(liquidityRanges, swapPayload);

        // #endregion do rebalance.

        // #region do swap 1 and 2.

        poolManager.unlock(abi.encode(1));
        // poolManager.unlock(abi.encode(3));

        // #endregion do swap 1 and 2.

        // #region change ranges.

        tickLower = (tick / 10) * 10 - (5 * 10);
        tickUpper = (tick / 10) * 10 + (5 * 10);

        liquidityRanges = new IUniV4StandardModule.LiquidityRange[](1);

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

        swapPayload = SwapPayload({
            payload: abi.encodeWithSelector(this.swap.selector),
            router: address(this),
            amountIn: 0.25 ether,
            expectedMinReturn: 856_625_000,
            zeroForOne: false
        });

        vm.prank(manager);
        vm.expectRevert(IUniV4StandardModule.SlippageTooHigh.selector);
        module.rebalance(liquidityRanges, swapPayload);

        // #endregion change ranges.
    }

    function testRebalanceSwapAndRebalanceWithSwapZeroForOneNative()
        public
    {
        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        Currency currency0 = Currency.wrap(address(0));
        Currency currency1 = Currency.wrap(USDC);

        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 10_000,
            tickSpacing: 20,
            hooks: IHooks(address(0))
        });

        sqrtPriceX96 = 4_073_749_093_844_602_324_196_220; // 2645,5 USDC/WETH.

        poolManager.unlock(abi.encode(2));

        ArrakisMetaVaultMock(metaVault).setTokens(USDC, NATIVE_COIN);

        {
            address implementation = address(
                new UniV4StandardModulePublic(
                    address(poolManager), guardian, COW_SWAP_ETH_FLOW
                )
            );

            bytes memory data = abi.encodeWithSelector(
                IUniV4StandardModule.initialize.selector,
                init0,
                init1,
                true,
                poolKey,
                IOracleWrapper(address(oracle)),
                TEN_PERCENT,
                metaVault
            );

            module = UniV4StandardModulePublic(
                payable(
                    address(new ERC1967Proxy(implementation, data))
                )
            );
        }

        vm.prank(address(manager));
        module.setManagerFeePIPS(10_000);

        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));
        {
            address depositor =
                vm.addr(uint256(keccak256(abi.encode("Depositor"))));

            // #region deposit.

            deal(USDC, depositor, init0);
            deal(metaVault, init1);

            vm.startPrank(depositor);
            IERC20Metadata(USDC).approve(address(module), init0);
            vm.stopPrank();

            vm.prank(metaVault);
            module.deposit{value: init1}(depositor, BASE);

            // #endregion deposit.

            assertEq(IERC20Metadata(USDC).balanceOf(depositor), 0);
            assertEq(depositor.balance, 0);
        }

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

        SwapPayload memory swapPayload;

        vm.prank(manager);
        module.rebalance(liquidityRanges, swapPayload);

        // #endregion do rebalance.

        // #region do swap 1 and 2.

        poolManager.unlock(abi.encode(4));

        // #endregion do swap 1 and 2.

        // #region change ranges.

        tickLower = (tick / 10) * 10 - (5 * 10);
        tickUpper = (tick / 10) * 10 + (5 * 10);

        liquidityRanges = new IUniV4StandardModule.LiquidityRange[](1);

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

        swapPayload = SwapPayload({
            payload: abi.encodeWithSelector(this.swapOne.selector),
            router: address(this),
            amountIn: 0.25 ether,
            expectedMinReturn: 656_625_000,
            zeroForOne: false
        });

        deal(address(poolManager), 0.26 ether);

        vm.prank(manager);
        module.rebalance(liquidityRanges, swapPayload);

        // #endregion change ranges.

        // #region withdraw.

        (uint256 amount0, uint256 amount1) = module.totalUnderlying();

        vm.prank(metaVault);
        module.withdraw(receiver, BASE);

        assertEq(IERC20Metadata(USDC).balanceOf(receiver), amount0);
        assertEq(receiver.balance, amount1);

        // #endregion withdraw.
    }

    function testRebalanceSwapAndRebalanceWithSwapZeroForOneGetNative(
    ) public {
        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        Currency currency0 = Currency.wrap(address(0));
        Currency currency1 = Currency.wrap(USDC);

        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 10_000,
            tickSpacing: 20,
            hooks: IHooks(address(0))
        });

        sqrtPriceX96 = 4_073_749_093_844_602_324_196_220; // 2645,5 USDC/WETH.

        poolManager.unlock(abi.encode(2));

        ArrakisMetaVaultMock(metaVault).setTokens(USDC, NATIVE_COIN);

        {
            address implementation = address(
                new UniV4StandardModulePublic(
                    address(poolManager), guardian, COW_SWAP_ETH_FLOW
                )
            );

            bytes memory data = abi.encodeWithSelector(
                IUniV4StandardModule.initialize.selector,
                init0,
                init1,
                true,
                poolKey,
                IOracleWrapper(address(oracle)),
                TEN_PERCENT,
                metaVault
            );

            module = UniV4StandardModulePublic(
                payable(
                    address(new ERC1967Proxy(implementation, data))
                )
            );
        }

        vm.prank(address(manager));
        module.setManagerFeePIPS(10_000);

        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));
        {
            address depositor =
                vm.addr(uint256(keccak256(abi.encode("Depositor"))));

            // #region deposit.

            deal(USDC, depositor, init0);
            deal(metaVault, init1);

            vm.startPrank(depositor);
            IERC20Metadata(USDC).approve(address(module), init0);
            vm.stopPrank();

            vm.prank(metaVault);
            module.deposit{value: init1}(depositor, BASE);

            // #endregion deposit.

            assertEq(IERC20Metadata(USDC).balanceOf(depositor), 0);
            assertEq(depositor.balance, 0);
        }

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

        SwapPayload memory swapPayload;

        vm.prank(manager);
        module.rebalance(liquidityRanges, swapPayload);

        // #endregion do rebalance.

        // #region do swap 1 and 2.

        poolManager.unlock(abi.encode(4));

        // #endregion do swap 1 and 2.

        // #region change ranges.

        tickLower = (tick / 10) * 10 - (5 * 10);
        tickUpper = (tick / 10) * 10 + (5 * 10);

        liquidityRanges = new IUniV4StandardModule.LiquidityRange[](1);

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

        swapPayload = SwapPayload({
            payload: abi.encodeWithSelector(this.swapOneNative.selector),
            router: address(this),
            amountIn: 656_625_000,
            expectedMinReturn: 0.25 ether,
            zeroForOne: true
        });

        deal(USDC, address(poolManager), 656_625_000);

        vm.prank(manager);
        module.rebalance(liquidityRanges, swapPayload);

        // #endregion change ranges.

        // #region withdraw.

        (uint256 amount0, uint256 amount1) = module.totalUnderlying();

        vm.prank(metaVault);
        module.withdraw(receiver, BASE);

        assertEq(IERC20Metadata(USDC).balanceOf(receiver), amount0);
        assertEq(receiver.balance, amount1);

        // #endregion withdraw.
    }

    function testRebalanceSwapAndRebalanceWithSwapExpectedMinReturnTooLow(
    ) public {
        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        Currency currency0 = Currency.wrap(address(0));
        Currency currency1 = Currency.wrap(USDC);

        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 10_000,
            tickSpacing: 20,
            hooks: IHooks(address(0))
        });

        sqrtPriceX96 = 4_073_749_093_844_602_324_196_220; // 2645,5 USDC/WETH.

        poolManager.unlock(abi.encode(2));

        ArrakisMetaVaultMock(metaVault).setTokens(USDC, NATIVE_COIN);

        {
            address implementation = address(
                new UniV4StandardModulePublic(
                    address(poolManager), guardian, COW_SWAP_ETH_FLOW
                )
            );

            bytes memory data = abi.encodeWithSelector(
                IUniV4StandardModule.initialize.selector,
                init0,
                init1,
                true,
                poolKey,
                IOracleWrapper(address(oracle)),
                TEN_PERCENT,
                metaVault
            );

            module = UniV4StandardModulePublic(
                payable(
                    address(new ERC1967Proxy(implementation, data))
                )
            );
        }

        vm.prank(address(manager));
        module.setManagerFeePIPS(10_000);

        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));
        {
            address depositor =
                vm.addr(uint256(keccak256(abi.encode("Depositor"))));

            // #region deposit.

            deal(USDC, depositor, init0);
            deal(metaVault, init1);

            vm.startPrank(depositor);
            IERC20Metadata(USDC).approve(address(module), init0);
            vm.stopPrank();

            vm.prank(metaVault);
            module.deposit{value: init1}(depositor, BASE);

            // #endregion deposit.

            assertEq(IERC20Metadata(USDC).balanceOf(depositor), 0);
            assertEq(depositor.balance, 0);
        }

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

        SwapPayload memory swapPayload;

        vm.prank(manager);
        module.rebalance(liquidityRanges, swapPayload);

        // #endregion do rebalance.

        // #region do swap 1 and 2.

        poolManager.unlock(abi.encode(4));

        // #endregion do swap 1 and 2.

        // #region compute oracle price.

        uint256 oraclePrice;

        uint8 decimals1 = 18;

        /// @dev native coin decimals.

        if (sqrtPriceX96 <= type(uint128).max) {
            oraclePrice = FullMath.mulDiv(
                uint256(sqrtPriceX96) * uint256(sqrtPriceX96),
                10 ** decimals1,
                1 << 192
            );
        } else {
            oraclePrice = FullMath.mulDiv(
                FullMath.mulDiv(
                    uint256(sqrtPriceX96),
                    uint256(sqrtPriceX96),
                    1 << 64
                ),
                10 ** decimals1,
                1 << 128
            );
        }

        oraclePrice = FullMath.mulDiv(oraclePrice, 120, 100);

        // #endregion compute oracle price.

        oracle.setPrice1(oraclePrice);

        // #region change ranges.

        tickLower = (tick / 10) * 10 - (5 * 10);
        tickUpper = (tick / 10) * 10 + (5 * 10);

        liquidityRanges = new IUniV4StandardModule.LiquidityRange[](1);

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

        swapPayload = SwapPayload({
            payload: abi.encodeWithSelector(this.swapOne.selector),
            router: address(this),
            amountIn: 0.25 ether,
            expectedMinReturn: 656_625_000,
            zeroForOne: false
        });

        vm.prank(manager);
        vm.expectRevert(
            IUniV4StandardModule.ExpectedMinReturnTooLow.selector
        );
        module.rebalance(liquidityRanges, swapPayload);

        // #endregion change ranges.
    }

    function testRebalanceSwapAndWithdraw() public {
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

        SwapPayload memory swapPayload;

        vm.prank(manager);
        module.rebalance(liquidityRanges, swapPayload);

        // #endregion do rebalance.

        // #region do swap 1 and 2.

        poolManager.unlock(abi.encode(1));
        poolManager.unlock(abi.encode(3));

        // #endregion do swap 1 and 2.

        (uint256 amount0, uint256 amount1) = module.totalUnderlying();

        // #region withdraw.

        vm.prank(metaVault);
        module.withdraw(receiver, BASE);

        assertEq(IERC20Metadata(USDC).balanceOf(receiver), amount0);
        assertEq(IERC20Metadata(WETH).balanceOf(receiver), amount1);

        assertEq(
            IERC20Metadata(USDC).balanceOf(address(manager)), 344
        );
        assertEq(
            IERC20Metadata(WETH).balanceOf(address(manager)),
            29_641_691_633_406
        );

        // #endregion withdraw.
    }

    function testRebalanceSwapAndCollect() public {
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

        SwapPayload memory swapPayload;

        vm.prank(manager);
        module.rebalance(liquidityRanges, swapPayload);

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
            liquidity: 0
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
            liquidity: 0
        });

        vm.prank(manager);
        vm.expectRevert(
            abi.encodeWithSelector(
                IUniV4StandardModule.RangeShouldBeActive.selector,
                tickLower,
                tickUpper
            )
        );
        module.rebalance(liquidityRanges, swapPayload);

        // #endregion change ranges.
    }

    function testRebalanceSwapAndRebalanceWithSwapOneForZero()
        public
    {
        uint256 init0 = 1e18;
        uint256 init1 = 3000e6;

        Currency currency0 = Currency.wrap(WETH);
        Currency currency1 = Currency.wrap(USDT);

        ArrakisMetaVaultMock(metaVault).setTokens(WETH, USDT);

        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 10_000,
            tickSpacing: 20,
            hooks: IHooks(address(0))
        });

        sqrtPriceX96 = 4_073_749_093_844_602_324_196_220; // 2645,5 USDC/WETH.

        poolManager.unlock(abi.encode(2));

        {
            address implementation = address(
                new UniV4StandardModulePublic(
                    address(poolManager), guardian, COW_SWAP_ETH_FLOW
                )
            );

            bytes memory data = abi.encodeWithSelector(
                IUniV4StandardModule.initialize.selector,
                init0,
                init1,
                false,
                poolKey,
                IOracleWrapper(address(oracle)),
                TEN_PERCENT,
                metaVault
            );

            module = UniV4StandardModulePublic(
                payable(
                    address(new ERC1967Proxy(implementation, data))
                )
            );
        }

        vm.prank(address(manager));
        module.setManagerFeePIPS(10_000);

        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));
        {
            address depositor =
                vm.addr(uint256(keccak256(abi.encode("Depositor"))));

            // #region deposit.

            deal(WETH, depositor, init0);

            address binanceHotWallet =
                0xF977814e90dA44bFA03b6295A0616a897441aceC;
            vm.prank(binanceHotWallet);
            IERC20USDT(USDT).transfer(depositor, init1);

            vm.startPrank(depositor);
            IERC20Metadata(WETH).approve(address(module), init0);
            IERC20USDT(USDT).approve(address(module), 0);
            IERC20USDT(USDT).approve(address(module), init1);
            vm.stopPrank();

            vm.prank(metaVault);
            module.deposit(depositor, BASE);

            // #endregion deposit.

            assertEq(IERC20Metadata(WETH).balanceOf(depositor), 0);
            assertEq(IERC20Metadata(USDT).balanceOf(depositor), 0);
        }

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

        SwapPayload memory swapPayload;

        vm.prank(manager);
        module.rebalance(liquidityRanges, swapPayload);

        // #endregion do rebalance.

        // #region do swap 1 and 2.

        poolManager.unlock(abi.encode(5));

        // #endregion do swap 1 and 2.

        // #region change ranges.

        tickLower = (tick / 10) * 10 - (5 * 10);
        tickUpper = (tick / 10) * 10 + (5 * 10);

        liquidityRanges = new IUniV4StandardModule.LiquidityRange[](1);

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

        swapPayload = SwapPayload({
            payload: abi.encodeWithSelector(this.swapUSDT.selector),
            router: address(this),
            amountIn: 0.25 ether,
            expectedMinReturn: 661_625_000,
            zeroForOne: true
        });

        vm.prank(manager);
        module.rebalance(liquidityRanges, swapPayload);

        // #endregion change ranges.

        // #region withdraw.

        (uint256 amount0, uint256 amount1) = module.totalUnderlying();

        vm.prank(metaVault);
        module.withdraw(receiver, BASE);

        assertEq(IERC20Metadata(USDT).balanceOf(receiver), amount1);
        assertEq(IERC20Metadata(WETH).balanceOf(receiver), amount0);

        // #endregion withdraw.
    }

    function testRebalanceSwapAndRebalanceWithSwapOneForZeroSlippageTooHigh(
    ) public {
        uint256 init0 = 1e18;
        uint256 init1 = 3000e6;

        Currency currency0 = Currency.wrap(WETH);
        Currency currency1 = Currency.wrap(USDT);

        ArrakisMetaVaultMock(metaVault).setTokens(WETH, USDT);

        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 10_000,
            tickSpacing: 20,
            hooks: IHooks(address(0))
        });

        sqrtPriceX96 = 4_073_749_093_844_602_324_196_220; // 2645,5 USDC/WETH.

        poolManager.unlock(abi.encode(2));

        {
            address implementation = address(
                new UniV4StandardModulePublic(
                    address(poolManager), guardian, COW_SWAP_ETH_FLOW
                )
            );

            bytes memory data = abi.encodeWithSelector(
                IUniV4StandardModule.initialize.selector,
                init0,
                init1,
                false,
                poolKey,
                IOracleWrapper(address(oracle)),
                TEN_PERCENT,
                metaVault
            );

            module = UniV4StandardModulePublic(
                payable(
                    address(new ERC1967Proxy(implementation, data))
                )
            );
        }

        vm.prank(address(manager));
        module.setManagerFeePIPS(10_000);

        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));
        {
            address depositor =
                vm.addr(uint256(keccak256(abi.encode("Depositor"))));

            // #region deposit.

            deal(WETH, depositor, init0);

            address binanceHotWallet =
                0xF977814e90dA44bFA03b6295A0616a897441aceC;
            vm.prank(binanceHotWallet);
            IERC20USDT(USDT).transfer(depositor, init1);

            vm.startPrank(depositor);
            IERC20Metadata(WETH).approve(address(module), init0);
            IERC20USDT(USDT).approve(address(module), 0);
            IERC20USDT(USDT).approve(address(module), init1);
            vm.stopPrank();

            vm.prank(metaVault);
            module.deposit(depositor, BASE);

            // #endregion deposit.

            assertEq(IERC20Metadata(WETH).balanceOf(depositor), 0);
            assertEq(IERC20Metadata(USDT).balanceOf(depositor), 0);
        }

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

        SwapPayload memory swapPayload;

        vm.prank(manager);
        module.rebalance(liquidityRanges, swapPayload);

        // #endregion do rebalance.

        // #region do swap 1 and 2.

        poolManager.unlock(abi.encode(5));

        // #endregion do swap 1 and 2.

        // #region change ranges.

        tickLower = (tick / 10) * 10 - (5 * 10);
        tickUpper = (tick / 10) * 10 + (5 * 10);

        liquidityRanges = new IUniV4StandardModule.LiquidityRange[](1);

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

        swapPayload = SwapPayload({
            payload: abi.encodeWithSelector(this.swapUSDT.selector),
            router: address(this),
            amountIn: 0.25 ether,
            expectedMinReturn: 861_625_000,
            zeroForOne: true
        });

        vm.prank(manager);
        vm.expectRevert(IUniV4StandardModule.SlippageTooHigh.selector);
        module.rebalance(liquidityRanges, swapPayload);

        // #endregion change ranges.
    }

    function testRebalanceSwapAndRebalanceWithSwapOneForZeroNATIVE()
        public
    {
        uint256 init0 = 1e18;
        uint256 init1 = 3000e6;

        Currency currency0 = Currency.wrap(address(0));
        Currency currency1 = Currency.wrap(USDT);

        ArrakisMetaVaultMock(metaVault).setTokens(NATIVE_COIN, USDT);

        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 10_000,
            tickSpacing: 20,
            hooks: IHooks(address(0))
        });

        sqrtPriceX96 = 4_073_749_093_844_602_324_196_220; // 2645,5 USDC/WETH.

        poolManager.unlock(abi.encode(2));

        {
            address implementation = address(
                new UniV4StandardModulePublic(
                    address(poolManager), guardian, COW_SWAP_ETH_FLOW
                )
            );

            bytes memory data = abi.encodeWithSelector(
                IUniV4StandardModule.initialize.selector,
                init0,
                init1,
                false,
                poolKey,
                IOracleWrapper(address(oracle)),
                TEN_PERCENT,
                metaVault
            );

            module = UniV4StandardModulePublic(
                payable(
                    address(new ERC1967Proxy(implementation, data))
                )
            );
        }

        vm.prank(address(manager));
        module.setManagerFeePIPS(10_000);

        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));
        {
            address depositor =
                vm.addr(uint256(keccak256(abi.encode("Depositor"))));

            // #region deposit.

            deal(metaVault, init0);

            address binanceHotWallet =
                0xF977814e90dA44bFA03b6295A0616a897441aceC;
            vm.prank(binanceHotWallet);
            IERC20USDT(USDT).transfer(depositor, init1);

            vm.startPrank(depositor);
            IERC20USDT(USDT).approve(address(module), 0);
            IERC20USDT(USDT).approve(address(module), init1);
            vm.stopPrank();

            vm.prank(metaVault);
            module.deposit{value: init0}(depositor, BASE);

            // #endregion deposit.

            assertEq(depositor.balance, 0);
            assertEq(IERC20Metadata(USDT).balanceOf(depositor), 0);
        }

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

        SwapPayload memory swapPayload;

        vm.prank(manager);
        module.rebalance(liquidityRanges, swapPayload);

        // #endregion do rebalance.

        // #region do swap 1 and 2.

        poolManager.unlock(abi.encode(6));

        // #endregion do swap 1 and 2.

        // #region change ranges.

        tickLower = (tick / 10) * 10 - (5 * 10);
        tickUpper = (tick / 10) * 10 + (5 * 10);

        liquidityRanges = new IUniV4StandardModule.LiquidityRange[](1);

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

        swapPayload = SwapPayload({
            payload: abi.encodeWithSelector(this.swapNATIVEUSDT.selector),
            router: address(this),
            amountIn: 0.25 ether,
            expectedMinReturn: 661_625_000,
            zeroForOne: true
        });

        vm.prank(manager);
        module.rebalance(liquidityRanges, swapPayload);

        // #endregion change ranges.

        // #region withdraw.

        (uint256 amount0, uint256 amount1) = module.totalUnderlying();

        vm.prank(metaVault);
        module.withdraw(receiver, BASE);

        assertEq(IERC20Metadata(USDT).balanceOf(receiver), amount1);
        assertEq(receiver.balance, amount0);

        // #endregion withdraw.
    }

    function testRebalanceSwapAndRebalanceWithSwapOneForZeroGetNATIVE(
    ) public {
        uint256 init0 = 1e18;
        uint256 init1 = 3000e6;

        Currency currency0 = Currency.wrap(address(0));
        Currency currency1 = Currency.wrap(USDT);

        ArrakisMetaVaultMock(metaVault).setTokens(NATIVE_COIN, USDT);

        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 10_000,
            tickSpacing: 20,
            hooks: IHooks(address(0))
        });

        sqrtPriceX96 = 4_073_749_093_844_602_324_196_220; // 2645,5 USDC/WETH.

        poolManager.unlock(abi.encode(2));

        {
            address implementation = address(
                new UniV4StandardModulePublic(
                    address(poolManager), guardian, COW_SWAP_ETH_FLOW
                )
            );

            bytes memory data = abi.encodeWithSelector(
                IUniV4StandardModule.initialize.selector,
                init0,
                init1,
                false,
                poolKey,
                IOracleWrapper(address(oracle)),
                TEN_PERCENT,
                metaVault
            );

            module = UniV4StandardModulePublic(
                payable(
                    address(new ERC1967Proxy(implementation, data))
                )
            );
        }

        vm.prank(address(manager));
        module.setManagerFeePIPS(10_000);

        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));
        {
            address depositor =
                vm.addr(uint256(keccak256(abi.encode("Depositor"))));

            // #region deposit.

            deal(metaVault, init0);

            address binanceHotWallet =
                0xF977814e90dA44bFA03b6295A0616a897441aceC;
            vm.prank(binanceHotWallet);
            IERC20USDT(USDT).transfer(depositor, init1);

            vm.startPrank(depositor);
            IERC20USDT(USDT).approve(address(module), 0);
            IERC20USDT(USDT).approve(address(module), init1);
            vm.stopPrank();

            vm.prank(metaVault);
            module.deposit{value: init0}(depositor, BASE);

            // #endregion deposit.

            assertEq(depositor.balance, 0);
            assertEq(IERC20Metadata(USDT).balanceOf(depositor), 0);
        }

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

        SwapPayload memory swapPayload;

        vm.prank(manager);
        module.rebalance(liquidityRanges, swapPayload);

        // #endregion do rebalance.

        // #region do swap 1 and 2.

        poolManager.unlock(abi.encode(6));

        // #endregion do swap 1 and 2.

        // #region change ranges.

        tickLower = (tick / 10) * 10 - (5 * 10);
        tickUpper = (tick / 10) * 10 + (5 * 10);

        liquidityRanges = new IUniV4StandardModule.LiquidityRange[](1);

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

        swapPayload = SwapPayload({
            payload: abi.encodeWithSelector(this.swapUSDTNATIVE.selector),
            router: address(this),
            amountIn: 661_625_000,
            expectedMinReturn: 0.25 ether,
            zeroForOne: false
        });

        vm.prank(manager);
        module.rebalance(liquidityRanges, swapPayload);

        // #endregion change ranges.

        // #region withdraw.

        (uint256 amount0, uint256 amount1) = module.totalUnderlying();

        vm.prank(metaVault);
        module.withdraw(receiver, BASE);

        assertEq(IERC20Metadata(USDT).balanceOf(receiver), amount1);
        assertEq(receiver.balance, amount0);

        // #endregion withdraw.
    }

    function testRebalanceSwapAndRebalanceWithSwapOneForZeroNATIVEExpectedMinReturnTooLow(
    ) public {
        uint256 init0 = 1e18;
        uint256 init1 = 3000e6;

        Currency currency0 = Currency.wrap(address(0));
        Currency currency1 = Currency.wrap(USDT);

        ArrakisMetaVaultMock(metaVault).setTokens(NATIVE_COIN, USDT);

        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 10_000,
            tickSpacing: 20,
            hooks: IHooks(address(0))
        });

        sqrtPriceX96 = 4_073_749_093_844_602_324_196_220; // 2645,5 USDC/WETH.

        poolManager.unlock(abi.encode(2));

        {
            address implementation = address(
                new UniV4StandardModulePublic(
                    address(poolManager), guardian, COW_SWAP_ETH_FLOW
                )
            );

            bytes memory data = abi.encodeWithSelector(
                IUniV4StandardModule.initialize.selector,
                init0,
                init1,
                false,
                poolKey,
                IOracleWrapper(address(oracle)),
                TEN_PERCENT,
                metaVault
            );

            module = UniV4StandardModulePublic(
                payable(
                    address(new ERC1967Proxy(implementation, data))
                )
            );
        }

        vm.prank(address(manager));
        module.setManagerFeePIPS(10_000);

        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));
        {
            address depositor =
                vm.addr(uint256(keccak256(abi.encode("Depositor"))));

            // #region deposit.

            deal(metaVault, init0);

            address binanceHotWallet =
                0xF977814e90dA44bFA03b6295A0616a897441aceC;
            vm.prank(binanceHotWallet);
            IERC20USDT(USDT).transfer(depositor, init1);

            vm.startPrank(depositor);
            IERC20USDT(USDT).approve(address(module), 0);
            IERC20USDT(USDT).approve(address(module), init1);
            vm.stopPrank();

            vm.prank(metaVault);
            module.deposit{value: init0}(depositor, BASE);

            // #endregion deposit.

            assertEq(depositor.balance, 0);
            assertEq(IERC20Metadata(USDT).balanceOf(depositor), 0);
        }

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

        SwapPayload memory swapPayload;

        vm.prank(manager);
        module.rebalance(liquidityRanges, swapPayload);

        // #endregion do rebalance.

        // #region do swap 1 and 2.

        poolManager.unlock(abi.encode(6));

        // #endregion do swap 1 and 2.

        // #region change ranges.

        tickLower = (tick / 10) * 10 - (5 * 10);
        tickUpper = (tick / 10) * 10 + (5 * 10);

        liquidityRanges = new IUniV4StandardModule.LiquidityRange[](1);

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

        swapPayload = SwapPayload({
            payload: abi.encodeWithSelector(this.swapNATIVEUSDT.selector),
            router: address(this),
            amountIn: 0.25 ether,
            expectedMinReturn: 661_625_000,
            zeroForOne: true
        });

        // #region compute oracle price.

        uint256 oraclePrice;

        uint8 decimals0 = 18;

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

        oraclePrice = FullMath.mulDiv(oraclePrice, 120, 100);

        oracle.setPrice0(oraclePrice);

        // #endregion compute oracle price.

        vm.prank(manager);
        vm.expectRevert(
            IUniV4StandardModule.ExpectedMinReturnTooLow.selector
        );
        module.rebalance(liquidityRanges, swapPayload);

        // #endregion change ranges.
    }

    function testRebalanceSwapAndRebalanceWithSwapWrongRouter()
        public
    {
        uint256 init0 = 1e18;
        uint256 init1 = 3000e6;

        Currency currency0 = Currency.wrap(address(0));
        Currency currency1 = Currency.wrap(USDT);

        ArrakisMetaVaultMock(metaVault).setTokens(NATIVE_COIN, USDT);

        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 10_000,
            tickSpacing: 20,
            hooks: IHooks(address(0))
        });

        sqrtPriceX96 = 4_073_749_093_844_602_324_196_220; // 2645,5 USDC/WETH.

        poolManager.unlock(abi.encode(2));

        {
            address implementation = address(
                new UniV4StandardModulePublic(
                    address(poolManager), guardian, COW_SWAP_ETH_FLOW
                )
            );

            bytes memory data = abi.encodeWithSelector(
                IUniV4StandardModule.initialize.selector,
                init0,
                init1,
                false,
                poolKey,
                IOracleWrapper(address(oracle)),
                TEN_PERCENT,
                metaVault
            );

            module = UniV4StandardModulePublic(
                payable(
                    address(new ERC1967Proxy(implementation, data))
                )
            );
        }

        vm.prank(address(manager));
        module.setManagerFeePIPS(10_000);

        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));
        {
            address depositor =
                vm.addr(uint256(keccak256(abi.encode("Depositor"))));

            // #region deposit.

            deal(metaVault, init0);

            address binanceHotWallet =
                0xF977814e90dA44bFA03b6295A0616a897441aceC;
            vm.prank(binanceHotWallet);
            IERC20USDT(USDT).transfer(depositor, init1);

            vm.startPrank(depositor);
            IERC20USDT(USDT).approve(address(module), 0);
            IERC20USDT(USDT).approve(address(module), init1);
            vm.stopPrank();

            vm.prank(metaVault);
            module.deposit{value: init0}(depositor, BASE);

            // #endregion deposit.

            assertEq(depositor.balance, 0);
            assertEq(IERC20Metadata(USDT).balanceOf(depositor), 0);
        }

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

        SwapPayload memory swapPayload;

        vm.prank(manager);
        module.rebalance(liquidityRanges, swapPayload);

        // #endregion do rebalance.

        // #region do swap 1 and 2.

        poolManager.unlock(abi.encode(6));

        // #endregion do swap 1 and 2.

        // #region change ranges.

        tickLower = (tick / 10) * 10 - (5 * 10);
        tickUpper = (tick / 10) * 10 + (5 * 10);

        liquidityRanges = new IUniV4StandardModule.LiquidityRange[](1);

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

        swapPayload = SwapPayload({
            payload: abi.encodeWithSelector(this.swapNATIVEUSDT.selector),
            router: metaVault,
            amountIn: 0.25 ether,
            expectedMinReturn: 661_625_000,
            zeroForOne: true
        });

        vm.prank(manager);
        vm.expectRevert(IUniV4StandardModule.WrongRouter.selector);
        module.rebalance(liquidityRanges, swapPayload);

        // #endregion change ranges.
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

        SwapPayload memory swapPayload;

        vm.prank(manager);
        module.rebalance(liquidityRanges, swapPayload);

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

    function testGetInitsInversed() public {
        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        Currency currency0 = Currency.wrap(address(0));
        Currency currency1 = Currency.wrap(USDC);

        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 10_000,
            tickSpacing: 20,
            hooks: IHooks(address(0))
        });

        sqrtPriceX96 = 4_073_749_093_844_602_324_196_220; // 2645,5 USDC/WETH.

        poolManager.unlock(abi.encode(2));

        ArrakisMetaVaultMock(metaVault).setTokens(USDC, NATIVE_COIN);

        {
            address implementation = address(
                new UniV4StandardModulePublic(
                    address(poolManager), guardian, COW_SWAP_ETH_FLOW
                )
            );

            bytes memory data = abi.encodeWithSelector(
                IUniV4StandardModule.initialize.selector,
                init0,
                init1,
                true,
                poolKey,
                IOracleWrapper(address(oracle)),
                TEN_PERCENT,
                metaVault
            );

            module = UniV4StandardModulePublic(
                payable(
                    address(new ERC1967Proxy(implementation, data))
                )
            );
        }

        (uint256 i0, uint256 i1) = module.getInits();

        assertEq(i0, 3000e6);
        assertEq(i1, 1e18);
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

        SwapPayload memory swapPayload;

        vm.prank(manager);
        module.rebalance(liquidityRanges, swapPayload);

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

        SwapPayload memory swapPayload;

        vm.prank(manager);
        module.rebalance(liquidityRanges, swapPayload);

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

    function testTotalUnderlyingAtPricInverse() public {
        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        {
            Currency currency0 = Currency.wrap(address(0));
            Currency currency1 = Currency.wrap(USDC);

            poolKey = PoolKey({
                currency0: currency0,
                currency1: currency1,
                fee: 10_000,
                tickSpacing: 20,
                hooks: IHooks(address(0))
            });
        }

        sqrtPriceX96 = 4_073_749_093_844_602_324_196_220; // 2645,5 USDC/WETH.

        poolManager.unlock(abi.encode(2));

        ArrakisMetaVaultMock(metaVault).setTokens(USDC, NATIVE_COIN);

        {
            address implementation = address(
                new UniV4StandardModulePublic(
                    address(poolManager), guardian, COW_SWAP_ETH_FLOW
                )
            );

            bytes memory data = abi.encodeWithSelector(
                IUniV4StandardModule.initialize.selector,
                init0,
                init1,
                true,
                poolKey,
                IOracleWrapper(address(oracle)),
                TEN_PERCENT,
                metaVault
            );

            module = UniV4StandardModulePublic(
                payable(
                    address(new ERC1967Proxy(implementation, data))
                )
            );
        }

        {
            address depositor =
                vm.addr(uint256(keccak256(abi.encode("Depositor"))));

            // #region deposit.

            deal(USDC, depositor, init0);
            deal(metaVault, init1);

            vm.startPrank(depositor);
            IERC20Metadata(USDC).approve(address(module), init0);
            vm.stopPrank();

            vm.prank(metaVault);
            module.deposit{value: init1}(depositor, BASE);

            // #endregion deposit.

            assertEq(IERC20Metadata(USDC).balanceOf(depositor), 0);
            assertEq(IERC20Metadata(WETH).balanceOf(depositor), 0);
        }

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

        SwapPayload memory swapPayload;

        vm.prank(manager);
        module.rebalance(liquidityRanges, swapPayload);

        // #endregion do rebalance.

        // #region compute new price.

        int24 newTick = tick + 10;

        uint160 newSqrtPrice = TickMath.getSqrtPriceAtTick(newTick);

        // #endregion compute new price.

        (uint256 amount0, uint256 amount1) =
            module.totalUnderlyingAtPrice(newSqrtPrice);

        assertGt(amount0, init0);
        assertLt(amount1, init1);
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
            new UniV4StandardModulePublic(
                address(poolManager), guardian, COW_SWAP_ETH_FLOW
            )
        );

        bytes memory data = abi.encodeWithSelector(
            IUniV4StandardModule.initialize.selector,
            init0,
            init1,
            false,
            poolKey,
            IOracleWrapper(address(oracle)),
            TEN_PERCENT,
            metaVault
        );

        module = UniV4StandardModulePublic(
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

        // #endregion compute oracle price.

        OracleMock oracle = new OracleMock();

        oracle.setPrice0(oraclePrice);

        uint24 maxDeviation = 10_010;

        module.validateRebalance(
            IOracleWrapper(address(oracle)), maxDeviation
        );
    }

    // #endregion test validateRebalance.

    // #region test managerBalance0.

    function testManagerBalance0() public {
        uint256 balance0 = module.managerBalance0();

        assertEq(balance0, 0);

        // #region do deposit, rebalance and swap.

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

        SwapPayload memory swapPayload;

        vm.prank(manager);
        module.rebalance(liquidityRanges, swapPayload);

        // #endregion do rebalance.

        // #region do swap 1 and 2.

        poolManager.unlock(abi.encode(1));
        poolManager.unlock(abi.encode(3));

        // #endregion do swap 1 and 2.

        // #endregion do deposit, rebalance and swap.

        balance0 = module.managerBalance0();

        assertEq(balance0, 344);
    }

    // #endregion test managerBalance0.

    // #region test managerBalance1.

    function testManagerBalance1() public {
        uint256 balance1 = module.managerBalance1();

        assertEq(balance1, 0);

        // #region do deposit, rebalance and swap.

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

        SwapPayload memory swapPayload;

        vm.prank(manager);
        module.rebalance(liquidityRanges, swapPayload);

        // #endregion do rebalance.

        // #region do swap 1 and 2.

        poolManager.unlock(abi.encode(1));
        poolManager.unlock(abi.encode(3));

        // #endregion do swap 1 and 2.

        // #endregion do deposit, rebalance and swap.

        balance1 = module.managerBalance1();

        assertEq(balance1, 29_641_691_633_406);
    }

    // #endregion test managerBalance0.

    // #region swap functions.

    function swap() external {
        IERC20Metadata(WETH).transferFrom(
            msg.sender, address(this), 0.25 ether
        );

        uint256 balance = IERC20Metadata(USDC).balanceOf(msg.sender);

        deal(USDC, msg.sender, 656_625_000 + balance);
    }

    function swapUSDT() external {
        IERC20Metadata(WETH).transferFrom(
            msg.sender, address(this), 0.25 ether
        );

        address binanceHotWallet =
            0xF977814e90dA44bFA03b6295A0616a897441aceC;
        vm.prank(binanceHotWallet);
        IERC20USDT(USDT).transfer(msg.sender, 661_625_000);
    }

    function swapNATIVEUSDT() external payable {
        address binanceHotWallet =
            0xF977814e90dA44bFA03b6295A0616a897441aceC;
        vm.prank(binanceHotWallet);
        IERC20USDT(USDT).transfer(msg.sender, 661_625_000);
    }

    function swapUSDTNATIVE() external {
        IERC20USDT(USDT).transferFrom(
            msg.sender, address(this), 661_625_000
        );

        uint256 balance = msg.sender.balance;

        deal(msg.sender, 0.25 ether + balance);
    }

    function swapOne() external payable {
        uint256 balance = IERC20Metadata(USDC).balanceOf(msg.sender);
        deal(USDC, msg.sender, 656_625_000 + balance);
    }

    function swapOneNative() external payable {
        IERC20Metadata(USDC).transferFrom(
            msg.sender, address(this), 656_625_000
        );

        uint256 balance = msg.sender.balance;

        deal(msg.sender, 0.25 ether + balance);
    }

    // #endregion swap functions.

    // #region view functions.

    function getDomainSeparatorV4(uint256 chainId_, address uniV4module_) public pure returns (bytes32 domainSeparator) {
        bytes32 typeHash = keccak256(
            'EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'
        );
        bytes32 hashedName = keccak256("UniswapV4StandardModule");
        bytes32 hashedVersion = keccak256("1.0.0");
        domainSeparator = keccak256(abi.encode(typeHash, hashedName, hashedVersion, chainId_, uniV4module_));
    }

    function getEOASignedOrder(
        Data memory data_,
        uint256 privateKey_,
        address uniV4module_,
        uint256 timestamp_,
        uint256 nonce_,
        bytes32 orderHash_
    ) public view returns (bytes memory signature) {
        bytes32 digest = keccak256(
            abi.encodePacked(
                '\x19\x01',
                getDomainSeparatorV4(block.chainid, uniV4module_),
                keccak256(abi.encode(IUniV4StandardModule(uniV4module_).DATA_TYPEHASH(), abi.encode(data_), timestamp_, nonce_, orderHash_))
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey_, digest);

        signature = abi.encodePacked(r, s, bytes1(v));
    }

    // #endregion view functions.

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

    function _lockAcquiredSwapWETHUSDT() internal {
        IPoolManager.SwapParams memory params = IPoolManager
            .SwapParams({
            zeroForOne: true,
            amountSpecified: 1_000_774_893,
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE * 2
        });
        poolManager.swap(poolKey, params, "");

        // #region settle currency.

        int256 currency1BalanceRaw = IPoolManager(
            address(poolManager)
        ).currencyDelta(address(this), poolKey.currency1);

        uint256 currency1Balance =
            SafeCast.toUint256(currency1BalanceRaw);

        int256 currency0BalanceRaw = IPoolManager(
            address(poolManager)
        ).currencyDelta(address(this), poolKey.currency0);

        uint256 currency0Balance =
            SafeCast.toUint256(-currency0BalanceRaw);

        if (currency1Balance > 0) {
            poolManager.take(
                poolKey.currency1, address(this), currency1Balance
            );
        }

        if (currency0Balance > 0) {
            poolManager.sync(poolKey.currency0);
            deal(WETH, address(this), currency0Balance);
            IERC20Metadata(WETH).transfer(
                address(poolManager), currency0Balance
            );
            poolManager.settle();
        }

        // #endregion settle currency.
    }

    function _lockAcquiredSwapETHUSDT() internal {
        IPoolManager.SwapParams memory params = IPoolManager
            .SwapParams({
            zeroForOne: true,
            amountSpecified: 1_000_774_893,
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE * 2
        });
        poolManager.swap(poolKey, params, "");

        // #region settle currency.

        int256 currency1BalanceRaw = IPoolManager(
            address(poolManager)
        ).currencyDelta(address(this), poolKey.currency1);

        uint256 currency1Balance =
            SafeCast.toUint256(currency1BalanceRaw);

        int256 currency0BalanceRaw = IPoolManager(
            address(poolManager)
        ).currencyDelta(address(this), poolKey.currency0);

        uint256 currency0Balance =
            SafeCast.toUint256(-currency0BalanceRaw);

        if (currency1Balance > 0) {
            poolManager.take(
                poolKey.currency1, address(this), currency1Balance
            );
        }

        if (currency0Balance > 0) {
            poolManager.sync(poolKey.currency0);
            deal(address(this), currency0Balance);
            poolManager.settle{value: currency0Balance}();
        }

        // #endregion settle currency.
    }

    function _lockAcquiredSwapNative() internal {
        IPoolManager.SwapParams memory params = IPoolManager
            .SwapParams({
            zeroForOne: true,
            amountSpecified: 1_000_774_893,
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
            poolManager.settle{value: currency0Balance}();
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
