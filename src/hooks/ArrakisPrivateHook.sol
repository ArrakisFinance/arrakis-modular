// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.25;

import {IArrakisPrivateHook} from "../interfaces/IArrakisPrivateHook.sol";
import {IArrakisLPModule} from "../interfaces/IArrakisLPModule.sol";
import {IArrakisMetaVault} from "../interfaces/IArrakisMetaVault.sol";

import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from
    "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from
    "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta} from
    "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";

contract ArrakisPrivateHook is IHooks, IArrakisPrivateHook {
    address public immutable module;

    uint24 public fee;
    address public poolManager;

    constructor(address module_) {
        if (module_ == address(0)) {
            revert AddressZero();
        }

        module = module_;
    }

    function setFee(PoolKey calldata poolKey_, uint24 fee_) external {
        if (msg.sender != IArrakisLPModule(module).metaVault().manager()) {
            revert OnlyVaultManager();
        }

        fee = fee_;
        IPoolManager(poolManager).updateDynamicLPFee(poolKey_, fee_);

        emit SetFee(fee_);
    }

    /// @notice The hook called before the state of a pool is initialized.
    /// @dev function not implemented, ArrakisPrivateHook will not support this hook.
    function beforeInitialize(
        address,
        PoolKey calldata,
        uint160,
        bytes calldata
    ) external virtual returns (bytes4) {
        poolManager = msg.sender;
    }

    /// @notice The hook called after the state of a pool is initialized.
    /// @dev function not implemented, ArrakisPrivateHook will not support this hook.
    function afterInitialize(
        address,
        PoolKey calldata,
        uint160,
        int24,
        bytes calldata
    ) external virtual returns (bytes4) {
        revert NotImplemented();
    }

    /// @notice The hook called before liquidity is added
    /// @param sender The initial msg.sender for the add liquidity call.
    function beforeAddLiquidity(
        address sender,
        PoolKey calldata,
        IPoolManager.ModifyLiquidityParams calldata,
        bytes calldata
    ) external virtual returns (bytes4) {
        if (sender != module) {
            revert OnlyModule();
        }

        return IHooks.beforeAddLiquidity.selector;
    }

    /// @notice The hook called after liquidity is added.
    /// @dev function not implemented, ArrakisPrivateHook will not support this hook.
    function afterAddLiquidity(
        address,
        PoolKey calldata,
        IPoolManager.ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) external virtual returns (bytes4, BalanceDelta) {
        revert NotImplemented();
    }

    /// @notice The hook called before liquidity is removed.
    /// @param sender The initial msg.sender for the remove liquidity call.
    function beforeRemoveLiquidity(
        address sender,
        PoolKey calldata,
        IPoolManager.ModifyLiquidityParams calldata,
        bytes calldata
    ) external virtual returns (bytes4) {
        if (sender != module) {
            revert OnlyModule();
        }

        return IHooks.beforeRemoveLiquidity.selector;
    }

    /// @notice The hook called after liquidity is removed.
    /// @dev function not implemented, ArrakisPrivateHook will not support this hook.
    function afterRemoveLiquidity(
        address,
        PoolKey calldata,
        IPoolManager.ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) external virtual returns (bytes4, BalanceDelta) {
        revert NotImplemented();
    }

    /// @notice The hook called before a swap.
    /// @dev function not implemented, ArrakisPrivateHook will not support this hook.
    function beforeSwap(
        address,
        PoolKey calldata,
        IPoolManager.SwapParams calldata,
        bytes calldata
    ) external virtual returns (bytes4, BeforeSwapDelta, uint24) {
        revert NotImplemented();
    }

    /// @notice The hook called after a swap.
    /// @dev function not implemented, ArrakisPrivateHook will not support this hook.
    function afterSwap(
        address,
        PoolKey calldata,
        IPoolManager.SwapParams calldata,
        BalanceDelta,
        bytes calldata
    ) external virtual returns (bytes4, int128) {
        revert NotImplemented();
    }

    /// @notice The hook called before donate.
    /// @dev function not implemented, ArrakisPrivateHook will not support this hook.
    function beforeDonate(
        address,
        PoolKey calldata,
        uint256,
        uint256,
        bytes calldata
    ) external virtual returns (bytes4) {
        revert NotImplemented();
    }

    /// @notice The hook called after donate.
    /// @dev function not implemented, ArrakisPrivateHook will not support this hook.
    function afterDonate(
        address,
        PoolKey calldata,
        uint256,
        uint256,
        bytes calldata
    ) external virtual returns (bytes4) {
        revert NotImplemented();
    }
}