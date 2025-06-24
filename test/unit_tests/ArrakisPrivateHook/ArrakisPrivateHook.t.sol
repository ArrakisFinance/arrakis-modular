// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// #region foundry.
import {console} from "forge-std/console.sol";
import {TestWrapper} from "../../utils/TestWrapper.sol";
// #endregion foundry.

import {IArrakisPrivateHook} from
    "../../../src/interfaces/IArrakisPrivateHook.sol";
import {
    ArrakisPrivateHook,
    LPFeeLibrary,
    Hooks
} from "../../../src/hooks/ArrakisPrivateHook.sol";
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
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {BalanceDelta} from
    "@uniswap/v4-core/src/types/BalanceDelta.sol";

// #region mocks.

import {ArrakisLPModuleMock} from "./mocks/ArrakisLPModuleMock.sol";
import {ArrakisMetaVaultMock} from "./mocks/ArrakisMetaVaultMock.sol";
import {ArrakisStandardManagerMock} from
    "./mocks/ArrakisStandardManagerMock.sol";
import {PoolManagerMock} from "./mocks/PoolManagerMock.sol";
import {ArrakisPrivateHookImplementation} from
    "./mocks/ArrakisPrivateHookImplementation.sol";

// #endregion mocks.

contract ArrakisPrivateHookTest is TestWrapper {
    using PoolIdLibrary for PoolKey;

    // #region constant properties.
    address public hook;
    address public module;
    address public vault;
    address public manager;
    uint24 public zeroForOneFee;
    uint24 public oneForZeroFee;
    address public executor;
    // #endregion constant properties.

    function setUp() public {
        executor = vm.addr(uint256(keccak256(abi.encode("Executor"))));

        // #region setup manager.
        manager = address(new ArrakisStandardManagerMock());
        ArrakisStandardManagerMock(manager).setExecutor(executor);
        // #endregion setup manager.

        // #region setup vault.
        vault = address(new ArrakisMetaVaultMock());
        ArrakisMetaVaultMock(vault).setManager(manager);
        // #endregion setup vault.

        // #region setup module.
        module = address(new ArrakisLPModuleMock());
        ArrakisLPModuleMock(module).setVault(vault);
        // #endregion setup module.

        ArrakisPrivateHook privateHook = ArrakisPrivateHook(
            address(
                uint160(
                    Hooks.BEFORE_ADD_LIQUIDITY_FLAG
                        | Hooks.BEFORE_SWAP_FLAG
                )
            )
        );

        hook = address(privateHook);

        vm.record();
        ArrakisPrivateHookImplementation impl =
            new ArrakisPrivateHookImplementation(manager, privateHook);
        (, bytes32[] memory writes) = vm.accesses(address(impl));
        vm.etch(address(privateHook), address(impl).code);
    }

    // #region test constructor.

    function testConstructorModuleAddressZero() public {
        vm.expectRevert(IArrakisPrivateHook.AddressZero.selector);
        hook = address(new ArrakisPrivateHook(address(0)));
    }

    function testConstructor() public {
        assertEq(IArrakisPrivateHook(hook).manager(), manager);
    }

    // #endregion test constructor.

    // #region test beforeInitialize.

    function testBeforeInitialize() public {
        address sender =
            vm.addr(uint256(keccak256(abi.encode("Sender"))));
        PoolKey memory key;
        uint160 sqrtPriceX96;

        vm.expectRevert(IArrakisPrivateHook.NotImplemented.selector);
        IHooks(hook).beforeInitialize(sender, key, sqrtPriceX96);
    }

    // #endregion test beforeInitialize.

    // #region test afterInitialize.

    function testAfterInitialize() public {
        address sender =
            vm.addr(uint256(keccak256(abi.encode("Sender"))));
        PoolKey memory key;
        uint160 sqrtPriceX96;
        int24 tick;

        vm.expectRevert(IArrakisPrivateHook.NotImplemented.selector);
        IHooks(hook).afterInitialize(sender, key, sqrtPriceX96, tick);
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
        IHooks(hook).beforeAddLiquidity(sender, key, params, hookData);
    }

    function testBeforeAddLiquidity() public {
        address sender = module;
        PoolKey memory key;
        IPoolManager.ModifyLiquidityParams memory params;
        bytes memory hookData;

        IArrakisPrivateHook.SetFeesData memory data =
            IArrakisPrivateHook.SetFeesData({
                module: module,
                zeroForOneFee: zeroForOneFee,
                oneForZeroFee: oneForZeroFee
            });

        vm.prank(executor);
        IArrakisPrivateHook(hook).setFees(
            key, data
        );

        vm.prank(module);
        IHooks(hook).beforeAddLiquidity(sender, key, params, hookData);
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

    function testBeforeRemoveLiquidityNotImplemented() public {
        address sender =
            vm.addr(uint256(keccak256(abi.encode("Sender"))));
        PoolKey memory key;
        IPoolManager.ModifyLiquidityParams memory params;
        bytes memory hookData;

        vm.expectRevert(IArrakisPrivateHook.NotImplemented.selector);
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

        zeroForOneFee = 1000;
        oneForZeroFee = 100_000;

        IArrakisPrivateHook.SetFeesData memory data =
            IArrakisPrivateHook.SetFeesData({
                module: module,
                zeroForOneFee: zeroForOneFee,
                oneForZeroFee: oneForZeroFee
            });

        params.zeroForOne = true;

        // #region set fees.

        vm.prank(executor);
        IArrakisPrivateHook(hook).setFees(
            key, data
        );

        // #endregion set fees.

        (,, uint24 lpFeeOverride) =
            IHooks(hook).beforeSwap(sender, key, params, hookData);

        assertEq(
            lpFeeOverride,
            zeroForOneFee | LPFeeLibrary.OVERRIDE_FEE_FLAG
        );
    }

    function testBeforeSwapBis() public {
        address sender =
            vm.addr(uint256(keccak256(abi.encode("Sender"))));
        PoolKey memory key;
        IPoolManager.SwapParams memory params;
        bytes memory hookData;

        // #region set fees.

        zeroForOneFee = 1000;
        oneForZeroFee = 100_000;

        IArrakisPrivateHook.SetFeesData memory data =
            IArrakisPrivateHook.SetFeesData({
                module: module,
                zeroForOneFee: zeroForOneFee,
                oneForZeroFee: oneForZeroFee
            });

        vm.prank(executor);
        IArrakisPrivateHook(hook).setFees(
            key, data
        );

        // #endregion set fees.

        (,, uint24 lpFeeOverride) =
            IHooks(hook).beforeSwap(sender, key, params, hookData);

        assertEq(
            lpFeeOverride,
            oneForZeroFee | LPFeeLibrary.OVERRIDE_FEE_FLAG
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
        IHooks(hook).afterSwap(sender, key, params, delta, hookData);
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

    // #region set fees.

    function testSetFeesOnlyExecutor() public {
        address notExecutor =
            vm.addr(uint256(keccak256(abi.encode("Not Executor"))));
        zeroForOneFee = 1000;
        oneForZeroFee = 10_000;

        PoolKey memory key;

        IArrakisPrivateHook.SetFeesData memory data =
            IArrakisPrivateHook.SetFeesData({
                module: module,
                zeroForOneFee: zeroForOneFee,
                oneForZeroFee: oneForZeroFee
            });

        vm.prank(notExecutor);
        vm.expectRevert(
            IArrakisPrivateHook.OnlyVaultExecutor.selector
        );
        IArrakisPrivateHook(hook).setFees(
            key,
            data
        );
    }

    function testSetFeesZeroForOneFeeNotValid() public {
        zeroForOneFee = 1_000_010;
        oneForZeroFee = 1000;

        PoolKey memory key;

        IArrakisPrivateHook.SetFeesData memory data =
            IArrakisPrivateHook.SetFeesData({
                module: module,
                zeroForOneFee: zeroForOneFee,
                oneForZeroFee: oneForZeroFee
            });

        vm.prank(executor);
        vm.expectRevert(
            abi.encodeWithSelector(
                LPFeeLibrary.LPFeeTooLarge.selector, zeroForOneFee
            )
        );
        IArrakisPrivateHook(hook).setFees(
            key,
            data
        );
    }

    function testSetFeesOneForZeroFeeNotValid() public {
        zeroForOneFee = 1000;
        oneForZeroFee = 1_000_001;

        PoolKey memory key;

        IArrakisPrivateHook.SetFeesData memory data =
            IArrakisPrivateHook.SetFeesData({
                module: module,
                zeroForOneFee: zeroForOneFee,
                oneForZeroFee: oneForZeroFee
            });

        vm.prank(executor);
        vm.expectRevert(
            abi.encodeWithSelector(
                LPFeeLibrary.LPFeeTooLarge.selector, oneForZeroFee
            )
        );
        IArrakisPrivateHook(hook).setFees(
            key,
            data
        );
    }

    function testSetFees() public {
        zeroForOneFee = 1000;
        oneForZeroFee = 100_000;

        PoolKey memory key;

        IArrakisPrivateHook.SetFeesData memory data =
            IArrakisPrivateHook.SetFeesData({
                module: module,
                zeroForOneFee: zeroForOneFee,
                oneForZeroFee: oneForZeroFee
            });

        vm.prank(executor);
        IArrakisPrivateHook(hook).setFees(
            key,
            data
        );

        assertEq(
            IArrakisPrivateHook(hook).zeroForOneFee(key.toId()), zeroForOneFee
        );
        assertEq(
            IArrakisPrivateHook(hook).oneForZeroFee(key.toId()), oneForZeroFee
        );
    }

    // #endregion set fees.
}
