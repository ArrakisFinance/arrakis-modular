// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// #region foundry.
import {console} from "forge-std/console.sol";
import {TestWrapper} from "../../utils/TestWrapper.sol";
// #endregion foundry.

// #region pancakeSwap Module.
import {PancakeSwapV4StandardModulePrivate} from
    "../../../src/modules/PancakeSwapV4StandardModulePrivate.sol";
import {IPancakeSwapV4StandardModule} from
    "../../../src/interfaces/IPancakeSwapV4StandardModule.sol";
import {IArrakisLPModule} from
    "../../../src/interfaces/IArrakisLPModule.sol";
import {IArrakisLPModulePrivate} from
    "../../../src/interfaces/IArrakisLPModulePrivate.sol";
import {IOracleWrapper} from
    "../../../src/interfaces/IOracleWrapper.sol";
import {IOwnable} from "../../../src/interfaces/IOwnable.sol";
import {
    BASE,
    PIPS,
    TEN_PERCENT,
    NATIVE_COIN
} from "../../../src/constants/CArrakis.sol";
import {SwapPayload} from "../../../src/structs/SPancakeSwapV4.sol";
// #endregion pancakeSwap Module.

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

// #region pancakeSwap.

import {ICLPoolManager} from
    "@pancakeswap/v4-core/src/pool-cl/interfaces/ICLPoolManager.sol";
import {CLPoolManager} from
    "@pancakeswap/v4-core/src/pool-cl/CLPoolManager.sol";
import {Vault, IVault} from "@pancakeswap/v4-core/src/Vault.sol";
import {
    Currency,
    CurrencyLibrary
} from "@pancakeswap/v4-core/src/types/Currency.sol";
import {PoolKey} from "@pancakeswap/v4-core/src/types/PoolKey.sol";
import {IHooks} from "@pancakeswap/v4-core/src/interfaces/IHooks.sol";
import {TickMath} from
    "@pancakeswap/v4-core/src/pool-cl/libraries/TickMath.sol";
import {FullMath} from
    "@pancakeswap/v4-core/src/pool-cl/libraries/FullMath.sol";
import {Hooks} from "@pancakeswap/v4-core/src/libraries/Hooks.sol";
import {CLPoolParametersHelper} from
    "@pancakeswap/v4-core/src/pool-cl/libraries/CLPoolParametersHelper.sol";
import {
    HOOKS_BEFORE_REMOVE_LIQUIDITY_OFFSET,
    HOOKS_AFTER_REMOVE_LIQUIDITY_OFFSET
} from "@pancakeswap/v4-core/src/pool-cl/interfaces/ICLHooks.sol";

// #endregion pancakeSwap.

import {LiquidityAmounts} from
    "@v3-lib-0.8/contracts/LiquidityAmounts.sol";

// #region mock contracts.
import {ArrakisMetaVaultMock} from "./mocks/ArrakisMetaVault.sol";
import {GuardianMock} from "./mocks/Guardian.sol";
import {OracleMock} from "./mocks/OracleWrapperMock.sol";
import {SimpleHook} from "./mocks/SimpleHook.sol";
// #endregion mock contracts.

interface IERC20USDT {
    function transfer(address _to, uint256 _value) external;
    function approve(address spender, uint256 value) external;
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external;
}

contract PancakeSwapV4StandardModulePrivateTest is TestWrapper {
    // #region constants.

    address public constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDT =
        0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public constant WETH =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    address public constant distributor =
        0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae;

    // #endregion constants.

    CLPoolManager public poolManager;
    Vault public pancakeVault;
    PoolKey public poolKey;
    uint160 public sqrtPriceX96;
    address public manager;
    address public pauser;
    address public metaVault;
    address public guardian;
    address public owner;
    address public collector;

    // #region mocks contracts.

    OracleMock public oracle;

    // #endregion mocks contracts.

    PancakeSwapV4StandardModulePrivate public module;

    function setUp() public {
        manager = vm.addr(uint256(keccak256(abi.encode("Manager"))));
        pauser = vm.addr(uint256(keccak256(abi.encode("Pauser"))));
        owner = vm.addr(uint256(keccak256(abi.encode("Owner"))));
        collector =
            vm.addr(uint256(keccak256(abi.encode("Collector"))));
        // #region meta vault creation.
        metaVault = address(new ArrakisMetaVaultMock(manager, owner));
        ArrakisMetaVaultMock(metaVault).setTokens(USDC, WETH);

        // #endregion meta vault creation.

        // #region create a guardian.

        guardian = address(new GuardianMock(pauser));

        // #endregion create a guardian.

        // #region do a poolManager deployment.

        address poolManagerOwner = vm.addr(
            uint256(keccak256(abi.encode("PoolManagerOwner")))
        );

        vm.prank(poolManagerOwner);
        pancakeVault = new Vault();
        poolManager = new CLPoolManager(pancakeVault);

        vm.prank(poolManagerOwner);
        pancakeVault.registerApp(address(poolManager));

        // #region create a pool.

        Currency currency0 = Currency.wrap(USDC);
        Currency currency1 = Currency.wrap(WETH);

        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            poolManager: poolManager,
            fee: 10_000,
            hooks: IHooks(address(0)),
            parameters: CLPoolParametersHelper.setTickSpacing(
                bytes32(0), 10
            )
        });

        sqrtPriceX96 = 1_356_476_084_642_877_807_665_053_548_195_417;

        pancakeVault.lock(abi.encode(2));

        // #endregion create a pool.

        // #region create an oracle.

        oracle = new OracleMock();

        // #endregion create an oracle.

        // #endregion do a poolManager deployment.

        // #region create uni v4 module.

        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        address implementation = address(
            new PancakeSwapV4StandardModulePrivate(
                address(poolManager),
                guardian,
                address(pancakeVault),
                distributor,
                collector
            )
        );

        bytes memory data = abi.encodeWithSelector(
            IPancakeSwapV4StandardModule.initialize.selector,
            init0,
            init1,
            false,
            poolKey,
            IOracleWrapper(address(oracle)),
            TEN_PERCENT,
            metaVault
        );

        module = PancakeSwapV4StandardModulePrivate(
            payable(address(new ERC1967Proxy(implementation, data)))
        );

        vm.prank(address(manager));
        module.setManagerFeePIPS(10_000);

        // #endregion create uni v4 module.
    }

    function lockAcquired(
        bytes calldata data
    ) public returns (bytes memory) {
        uint256 typeOfLockAcquired = abi.decode(data, (uint256));

        if (typeOfLockAcquired == 2) {
            poolManager.initialize(poolKey, sqrtPriceX96);
        }
    }

    // #region test fund.

    function testFundOnlyMetaVault() public {
        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));

        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisLPModule.OnlyMetaVault.selector,
                address(this),
                address(metaVault)
            )
        );

        module.fund(depositor, 0, 0);
    }

    function testFundDepositorDepositZero() public {
        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));

        vm.expectRevert(IArrakisLPModulePrivate.DepositZero.selector);

        vm.prank(metaVault);
        module.fund(depositor, 0, 0);
    }

    function testFund() public {
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
        module.fund(depositor, init0, init1);
    }

    function testFundNative() public {
        Currency currency0 = CurrencyLibrary.NATIVE; // NATIVE COIN
        Currency currency1 = Currency.wrap(USDC);

        ArrakisMetaVaultMock(metaVault).setTokens(USDC, NATIVE_COIN);

        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            poolManager: poolManager,
            fee: 10_000,
            hooks: IHooks(address(0)),
            parameters: CLPoolParametersHelper.setTickSpacing(
                bytes32(0), 10
            )
        });

        sqrtPriceX96 = 4_363_802_021_784_129_436_505_493;

        pancakeVault.lock(abi.encode(2));

        // #region create uni v4 module.

        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        address implementation = address(
            new PancakeSwapV4StandardModulePrivate(
                address(poolManager),
                guardian,
                address(pancakeVault),
                distributor,
                collector
            )
        );

        bytes memory data = abi.encodeWithSelector(
            IPancakeSwapV4StandardModule.initialize.selector,
            init0,
            init1,
            true,
            poolKey,
            IOracleWrapper(address(oracle)),
            TEN_PERCENT,
            metaVault
        );

        module = PancakeSwapV4StandardModulePrivate(
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
        module.fund{value: 1 ether}(depositor, init0, init1);
    }

    function testFundNativeOverPay() public {
        Currency currency0 = CurrencyLibrary.NATIVE; // NATIVE COIN
        Currency currency1 = Currency.wrap(USDC);

        ArrakisMetaVaultMock(metaVault).setTokens(USDC, NATIVE_COIN);

        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            poolManager: poolManager,
            fee: 10_000,
            hooks: IHooks(address(0)),
            parameters: CLPoolParametersHelper.setTickSpacing(
                bytes32(0), 10
            )
        });

        sqrtPriceX96 = 4_363_802_021_784_129_436_505_493;

        pancakeVault.lock(abi.encode(2));

        // #region create uni v4 module.

        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        address implementation = address(
            new PancakeSwapV4StandardModulePrivate(
                address(poolManager),
                guardian,
                address(pancakeVault),
                distributor,
                collector
            )
        );

        bytes memory data = abi.encodeWithSelector(
            IPancakeSwapV4StandardModule.initialize.selector,
            init0,
            init1,
            true,
            poolKey,
            IOracleWrapper(address(oracle)),
            TEN_PERCENT,
            metaVault
        );

        module = PancakeSwapV4StandardModulePrivate(
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
        module.fund{value: 2 ether}(depositor, init0, init1);
    }

    function testFundNativeUnderPay() public {
        Currency currency0 = CurrencyLibrary.NATIVE; // NATIVE COIN
        Currency currency1 = Currency.wrap(USDC);

        ArrakisMetaVaultMock(metaVault).setTokens(USDC, NATIVE_COIN);

        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            poolManager: poolManager,
            fee: 10_000,
            hooks: IHooks(address(0)),
            parameters: CLPoolParametersHelper.setTickSpacing(
                bytes32(0), 10
            )
        });

        sqrtPriceX96 = 4_363_802_021_784_129_436_505_493;

        pancakeVault.lock(abi.encode(2));

        // #region create uni v4 module.

        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        address implementation = address(
            new PancakeSwapV4StandardModulePrivate(
                address(poolManager),
                guardian,
                address(pancakeVault),
                distributor,
                collector
            )
        );

        bytes memory data = abi.encodeWithSelector(
            IPancakeSwapV4StandardModule.initialize.selector,
            init0,
            init1,
            true,
            poolKey,
            IOracleWrapper(address(oracle)),
            TEN_PERCENT,
            metaVault
        );

        module = PancakeSwapV4StandardModulePrivate(
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
        vm.expectRevert(
            IPancakeSwapV4StandardModule.InvalidMsgValue.selector
        );
        module.fund{value: 0.5 ether}(depositor, init0, init1);
    }

    function testFundNativeIsToken0() public {
        Currency currency0 = CurrencyLibrary.NATIVE; // NATIVE COIN
        Currency currency1 = Currency.wrap(USDT);

        ArrakisMetaVaultMock(metaVault).setTokens(NATIVE_COIN, USDT);

        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            poolManager: poolManager,
            fee: 10_000,
            hooks: IHooks(address(0)),
            parameters: CLPoolParametersHelper.setTickSpacing(
                bytes32(0), 10
            )
        });

        sqrtPriceX96 = 4_363_802_021_784_129_436_505_493;

        pancakeVault.lock(abi.encode(2));

        // #region create uni v4 module.

        uint256 init0 = 1e18;
        uint256 init1 = 3000e6;

        address implementation = address(
            new PancakeSwapV4StandardModulePrivate(
                address(poolManager),
                guardian,
                address(pancakeVault),
                distributor,
                collector
            )
        );

        bytes memory data = abi.encodeWithSelector(
            IPancakeSwapV4StandardModule.initialize.selector,
            init0,
            init1,
            false,
            poolKey,
            IOracleWrapper(address(oracle)),
            TEN_PERCENT,
            metaVault
        );

        module = PancakeSwapV4StandardModulePrivate(
            payable(address(new ERC1967Proxy(implementation, data)))
        );

        vm.prank(address(manager));
        module.setManagerFeePIPS(10_000);

        // #endregion create uni v4 module.

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));

        address binanceHotWallet =
            0xF977814e90dA44bFA03b6295A0616a897441aceC;
        vm.prank(binanceHotWallet);
        IERC20USDT(USDT).transfer(depositor, init1);
        deal(metaVault, init0);

        vm.startPrank(depositor);
        IERC20USDT(USDT).approve(address(module), 0);
        IERC20USDT(USDT).approve(address(module), init1);
        vm.stopPrank();

        vm.prank(metaVault);
        module.fund{value: 1 ether}(depositor, init0, init1);
    }

    function testFundNativeIsToken0OverPay() public {
        Currency currency0 = CurrencyLibrary.NATIVE; // NATIVE COIN
        Currency currency1 = Currency.wrap(USDT);

        ArrakisMetaVaultMock(metaVault).setTokens(NATIVE_COIN, USDT);

        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            poolManager: poolManager,
            fee: 10_000,
            hooks: IHooks(address(0)),
            parameters: CLPoolParametersHelper.setTickSpacing(
                bytes32(0), 10
            )
        });

        sqrtPriceX96 = 4_363_802_021_784_129_436_505_493;

        pancakeVault.lock(abi.encode(2));

        // #region create uni v4 module.

        uint256 init0 = 1e18;
        uint256 init1 = 3000e6;

        address implementation = address(
            new PancakeSwapV4StandardModulePrivate(
                address(poolManager),
                guardian,
                address(pancakeVault),
                distributor,
                collector
            )
        );

        bytes memory data = abi.encodeWithSelector(
            IPancakeSwapV4StandardModule.initialize.selector,
            init0,
            init1,
            false,
            poolKey,
            IOracleWrapper(address(oracle)),
            TEN_PERCENT,
            metaVault
        );

        module = PancakeSwapV4StandardModulePrivate(
            payable(address(new ERC1967Proxy(implementation, data)))
        );

        vm.prank(address(manager));
        module.setManagerFeePIPS(10_000);

        // #endregion create uni v4 module.

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));

        address binanceHotWallet =
            0xF977814e90dA44bFA03b6295A0616a897441aceC;
        vm.prank(binanceHotWallet);
        IERC20USDT(USDT).transfer(depositor, init1);
        deal(metaVault, 2 ether);

        vm.startPrank(depositor);
        IERC20USDT(USDT).approve(address(module), 0);
        IERC20USDT(USDT).approve(address(module), init1);
        vm.stopPrank();

        vm.prank(metaVault);
        module.fund{value: 2 ether}(depositor, init0, init1);
    }

    function testFundNativeIsToken0UnderPay() public {
        Currency currency0 = CurrencyLibrary.NATIVE; // NATIVE COIN
        Currency currency1 = Currency.wrap(USDT);

        ArrakisMetaVaultMock(metaVault).setTokens(NATIVE_COIN, USDT);

        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            poolManager: poolManager,
            fee: 10_000,
            hooks: IHooks(address(0)),
            parameters: CLPoolParametersHelper.setTickSpacing(
                bytes32(0), 10
            )
        });

        sqrtPriceX96 = 4_363_802_021_784_129_436_505_493;

        pancakeVault.lock(abi.encode(2));

        // #region create uni v4 module.

        uint256 init0 = 1e18;
        uint256 init1 = 3000e6;

        address implementation = address(
            new PancakeSwapV4StandardModulePrivate(
                address(poolManager),
                guardian,
                address(pancakeVault),
                distributor,
                collector
            )
        );

        bytes memory data = abi.encodeWithSelector(
            IPancakeSwapV4StandardModule.initialize.selector,
            init0,
            init1,
            false,
            poolKey,
            IOracleWrapper(address(oracle)),
            TEN_PERCENT,
            metaVault
        );

        module = PancakeSwapV4StandardModulePrivate(
            payable(address(new ERC1967Proxy(implementation, data)))
        );

        vm.prank(address(manager));
        module.setManagerFeePIPS(10_000);

        // #endregion create uni v4 module.

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));

        address binanceHotWallet =
            0xF977814e90dA44bFA03b6295A0616a897441aceC;
        vm.prank(binanceHotWallet);
        IERC20USDT(USDT).transfer(depositor, init1);
        deal(metaVault, 2 ether);

        vm.startPrank(depositor);
        IERC20USDT(USDT).approve(address(module), 0);
        IERC20USDT(USDT).approve(address(module), init1);
        vm.stopPrank();

        vm.prank(metaVault);
        vm.expectRevert(
            IPancakeSwapV4StandardModule.InvalidMsgValue.selector
        );
        module.fund{value: 0.5 ether}(depositor, init0, init1);
    }

    // #endregion test fund.

    // #region test withdraw.

    function testWithdraw() public {
        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));
        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));

        deal(USDC, depositor, init0);
        deal(WETH, depositor, init1);

        vm.startPrank(depositor);
        IERC20Metadata(USDC).approve(address(module), init0);
        IERC20Metadata(WETH).approve(address(module), init1);
        vm.stopPrank();

        vm.prank(metaVault);
        module.fund(depositor, init0, init1);

        (uint256 amount0, uint256 amount1) = module.totalUnderlying();

        vm.prank(metaVault);
        module.withdraw(receiver, BASE);
    }

    // #endregion test withdraw.

    // #region unlockCallback.

    function testLockAcquired() public {
        vm.expectRevert(
            IPancakeSwapV4StandardModule.OnlyVault.selector
        );
        module.lockAcquired("");
    }

    // #endregion unlockCallback.
}
