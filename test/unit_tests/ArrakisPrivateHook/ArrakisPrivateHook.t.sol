// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// #region foundry.
import {console} from "forge-std/console.sol";
import {TestWrapper} from "../../utils/TestWrapper.sol";
// #endregion foundry.

import {IArrakisPrivateHook} from
    "../../../src/interfaces/IArrakisPrivateHook.sol";
import {ArrakisPrivateHook} from
    "../../../src/hooks/ArrakisPrivateHook.sol";
import {IArrakisMetaVault} from
    "../../../src/interfaces/IArrakisMetaVault.sol";
import {IArrakisStandardManager} from
    "../../../src/interfaces/IArrakisStandardManager.sol";
import {IArrakisLPModule} from
    "../../../src/interfaces/IArrakisLPModule.sol";

import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from
    "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from
    "@uniswap/v4-core/src/types/BalanceDelta.sol";

// #region mocks.

import {ArrakisLPModuleMock} from "./mocks/ArrakisLPModuleMock.sol";
import {ArrakisMetaVaultMock} from "./mocks/ArrakisMetaVaultMock.sol";
import {ArrakisStandardManagerMock} from
    "./mocks/ArrakisStandardManagerMock.sol";
import {PoolManagerMock} from "./mocks/PoolManagerMock.sol";

// #endregion mocks.

contract ArrakisPrivateHookTest is TestWrapper {
    // #region constant properties.
    address public hook;
    address public module;
    address public vault;
    address public manager;
    uint24 public fee;
    address public poolManager;
    address public executor;
    // #endregion constant properties.

    function setUp() public {
        executor = vm.addr(uint256(keccak256(abi.encode("Executor"))));

        // #region setup manager.
        manager = address(new ArrakisStandardManagerMock());
        ArrakisStandardManagerMock(manager).setExecutor(executor);
        // #endregion setup manager.

        // #region setup poolManager.
        poolManager = address(new PoolManagerMock());
        // #endregion setup poolManager.

        // #region setup vault.
        vault = address(new ArrakisMetaVaultMock());
        ArrakisMetaVaultMock(vault).setManager(manager);
        // #endregion setup vault.

        // #region setup module.
        module = address(new ArrakisLPModuleMock());
        ArrakisLPModuleMock(module).setVault(vault);
        // #endregion setup module.

        hook = address(new ArrakisPrivateHook(module, poolManager));
    }

    // #region test constructor.

    function testConstructorModuleAddressZero() public {
        vm.expectRevert(IArrakisPrivateHook.AddressZero.selector);
        hook =
            address(new ArrakisPrivateHook(address(0), poolManager));
    }

    function testConstructorPoolManagerAddressZero() public {
        vm.expectRevert(IArrakisPrivateHook.AddressZero.selector);
        hook = address(new ArrakisPrivateHook(module, address(0)));
    }

    function testConstructorPoolManagerAndModuleAddressZeros()
        public
    {
        vm.expectRevert(IArrakisPrivateHook.AddressZero.selector);
        hook = address(new ArrakisPrivateHook(address(0), address(0)));
    }

    function testConstructor() public {
        assertEq(IArrakisPrivateHook(hook).module(), module);
        assertEq(IArrakisPrivateHook(hook).manager(), manager);
        assertEq(IArrakisPrivateHook(hook).poolManager(), poolManager);
        assertEq(IArrakisPrivateHook(hook).vault(), vault);
    }

    // #endregion test constructor.

    // #region test beforeInitialize.

    function testBeforeInitialize() public {
        address sender =
            vm.addr(uint256(keccak256(abi.encode("Sender"))));
        PoolKey memory key;
        uint160 sqrtPriceX96;
        bytes memory hookData;

        vm.expectRevert(IArrakisPrivateHook.NotImplemented.selector);
        IHooks(hook).beforeInitialize(
            sender, key, sqrtPriceX96, hookData
        );
    }

    // #endregion test beforeInitialize.

    // #region test afterInitialize.

    function testAfterInitialize() public {
        address sender =
            vm.addr(uint256(keccak256(abi.encode("Sender"))));
        PoolKey memory key;
        uint160 sqrtPriceX96;
        int24 tick;
        bytes memory hookData;

        vm.expectRevert(IArrakisPrivateHook.NotImplemented.selector);
        IHooks(hook).afterInitialize(
            sender, key, sqrtPriceX96, tick, hookData
        );
    }

    // #endregion test afterInitialize.

    // #region test beforeAddLiquidity.

    function testBeforeAddLiquidityOnlyModule() public {
        address sender =
            vm.addr(uint256(keccak256(abi.encode("Sender"))));
        PoolKey memory key;
        IPoolManager.ModifyLiquidityParams memory params;
        bytes memory hookData;

        vm.expectRevert(IArrakisPrivateHook.OnlyModule.selector);
        IHooks(hook).beforeAddLiquidity(
            sender, key, params, hookData
        );
    }

    function testBeforeAddLiquidity() public {
        address sender = module;
        PoolKey memory key;
        IPoolManager.ModifyLiquidityParams memory params;
        bytes memory hookData;

        vm.prank(module);
        IHooks(hook).beforeAddLiquidity(
            sender, key, params, hookData
        );
    }

    // #endregion test beforeAddLiquidity.

    // #region test afterAddLiquidity.

    function testAfterAddLiquidity() public {
        address sender =
            vm.addr(uint256(keccak256(abi.encode("Sender"))));
        PoolKey memory key;
        IPoolManager.ModifyLiquidityParams memory params;
        BalanceDelta delta;
        BalanceDelta feesAccrued;
        bytes memory hookData;

        vm.expectRevert(IArrakisPrivateHook.NotImplemented.selector);
        IHooks(hook).afterAddLiquidity(
            sender, key, params, delta, feesAccrued, hookData
        );
    }

    // #endregion test afterAddLiquidity.

    // #region test beforeRemoveLiquidity.

    function testBeforeRemoveLiquidityOnlyModule() public {
        address sender =
            vm.addr(uint256(keccak256(abi.encode("Sender"))));
        PoolKey memory key;
        IPoolManager.ModifyLiquidityParams memory params;
        bytes memory hookData;

        vm.expectRevert(IArrakisPrivateHook.OnlyModule.selector);
        IHooks(hook).beforeRemoveLiquidity(
            sender, key, params, hookData
        );
    }

    function testBeforeRemoveLiquidity() public {
        address sender = module;
        PoolKey memory key;
        IPoolManager.ModifyLiquidityParams memory params;
        bytes memory hookData;

        vm.prank(module);
        IHooks(hook).beforeRemoveLiquidity(
            sender, key, params, hookData
        );
    }

    // #endregion test beforeAddLiquidity.

    // #region test afterRemoveLiquidity.

    function testAfterRemoveLiquidity() public {
        address sender =
            vm.addr(uint256(keccak256(abi.encode("Sender"))));
        PoolKey memory key;
        IPoolManager.ModifyLiquidityParams memory params;
        BalanceDelta delta;
        BalanceDelta feesAccrued;
        bytes memory hookData;

        vm.expectRevert(IArrakisPrivateHook.NotImplemented.selector);
        IHooks(hook).afterRemoveLiquidity(
            sender, key, params, delta, feesAccrued, hookData
        );
    }

    // #endregion test afterRemoveLiquidity.

    // #region test beforeSwap.

    function testBeforeSwap() public {
        address sender =
            vm.addr(uint256(keccak256(abi.encode("Sender"))));
        PoolKey memory key;
        IPoolManager.SwapParams memory params;
        bytes memory hookData;

        vm.expectRevert(IArrakisPrivateHook.NotImplemented.selector);
        IHooks(hook).beforeSwap(
            sender, key, params, hookData
        );
    }

    // #endregion test beforeSwap.

    // #region test afterSwap.

    function testAfterSwap() public {
        address sender =
            vm.addr(uint256(keccak256(abi.encode("Sender"))));
        PoolKey memory key;
        IPoolManager.SwapParams memory params;
        BalanceDelta delta;
        bytes memory hookData;

        vm.expectRevert(IArrakisPrivateHook.NotImplemented.selector);
        IHooks(hook).afterSwap(
            sender, key, params, delta, hookData
        );
    }

    // #endregion test afterSwap.

    // #region test beforeDonate.

    function testBeforeDonate() public {
        address sender =
            vm.addr(uint256(keccak256(abi.encode("Sender"))));
        PoolKey memory key;
        uint256 amount0;
        uint256 amount1;
        bytes memory hookData;

        vm.expectRevert(IArrakisPrivateHook.NotImplemented.selector);
        IHooks(hook).beforeDonate(
            sender, key, amount0, amount1, hookData
        );
    }

    // #endregion test beforeDonate.

    // #region test afterDonate.

    function testAfterDonate() public {
        address sender =
            vm.addr(uint256(keccak256(abi.encode("Sender"))));
        PoolKey memory key;
        uint256 amount0;
        uint256 amount1;
        bytes memory hookData;

        vm.expectRevert(IArrakisPrivateHook.NotImplemented.selector);
        IHooks(hook).afterDonate(
            sender, key, amount0, amount1, hookData
        );
    }

    // #endregion test afterDonate.

    // #region set fee.

    function testSetFeeOnlyExecutor() public {
        address notExecutor = vm.addr(uint256(keccak256(abi.encode("Not Executor"))));
        fee = 1000;

        PoolKey memory key;

        vm.prank(notExecutor);
        vm.expectRevert(IArrakisPrivateHook.OnlyVaultExecutor.selector);
        IArrakisPrivateHook(hook).setFee(key, fee);
    }

    function testSetFee() public {
        fee = 1000;

        PoolKey memory key;

        vm.prank(executor);
        IArrakisPrivateHook(hook).setFee(key, fee);

        assertEq(PoolManagerMock(poolManager).fee(), fee);
    }
 
    // #endregion set fee.
}
