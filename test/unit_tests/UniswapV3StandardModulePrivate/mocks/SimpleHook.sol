// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "@pancakeswap/v4-core/src/pool-cl/interfaces/ICLHooks.sol";
import {PoolKey} from "@pancakeswap/v4-core/src/types/PoolKey.sol";
import {ICLPoolManager} from
    "@pancakeswap/v4-core/src/pool-cl/interfaces/ICLPoolManager.sol";
import {BalanceDelta} from
    "@pancakeswap/v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta} from
    "@pancakeswap/v4-core/src/types/BeforeSwapDelta.sol";

contract SimpleHook is ICLHooks {
    // #region structs.

    struct Permissions {
        bool beforeInitialize;
        bool afterInitialize;
        bool beforeAddLiquidity;
        bool afterAddLiquidity;
        bool beforeRemoveLiquidity;
        bool afterRemoveLiquidity;
        bool beforeSwap;
        bool afterSwap;
        bool beforeDonate;
        bool afterDonate;
        bool befreSwapReturnsDelta;
        bool afterSwapReturnsDelta;
        bool afterAddLiquidityReturnsDelta;
        bool afterRemoveLiquidityReturnsDelta;
    }

    // #endregion structs.

    // #region errors.

    error NotImplemented();

    // #endregion errors.

    function getHooksRegistrationBitmap()
        external
        view
        returns (uint16)
    {
        return _hooksRegistrationBitmapFrom(
            Permissions({
                beforeInitialize: false,
                afterInitialize: false,
                beforeAddLiquidity: false,
                afterAddLiquidity: false,
                beforeRemoveLiquidity: false,
                afterRemoveLiquidity: true,
                beforeSwap: false,
                afterSwap: false,
                beforeDonate: false,
                afterDonate: false,
                befreSwapReturnsDelta: false,
                afterSwapReturnsDelta: false,
                afterAddLiquidityReturnsDelta: false,
                afterRemoveLiquidityReturnsDelta: false
            })
        );
    }

    function beforeInitialize(
        address sender,
        PoolKey calldata key,
        uint160 sqrtPriceX96
    ) external returns (bytes4) {
        revert NotImplemented();
    }

    function afterInitialize(
        address sender,
        PoolKey calldata key,
        uint160 sqrtPriceX96,
        int24 tick
    ) external returns (bytes4) {
        revert NotImplemented();
    }

    function beforeAddLiquidity(
        address sender,
        PoolKey calldata key,
        ICLPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external returns (bytes4) {
        revert NotImplemented();
    }

    function afterAddLiquidity(
        address sender,
        PoolKey calldata key,
        ICLPoolManager.ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta,
        bytes calldata hookData
    ) external returns (bytes4, BalanceDelta) {
        revert NotImplemented();
    }

    function beforeRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        ICLPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external returns (bytes4) {
        return ICLHooks.beforeRemoveLiquidity.selector;
    }

    function afterRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        ICLPoolManager.ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta,
        bytes calldata hookData
    ) external returns (bytes4, BalanceDelta) {
        revert NotImplemented();
    }

    function beforeSwap(
        address sender,
        PoolKey calldata key,
        ICLPoolManager.SwapParams calldata params,
        bytes calldata hookData
    ) external returns (bytes4, BeforeSwapDelta, uint24) {
        revert NotImplemented();
    }

    function afterSwap(
        address sender,
        PoolKey calldata key,
        ICLPoolManager.SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) external returns (bytes4, int128) {
        revert NotImplemented();
    }

    function beforeDonate(
        address sender,
        PoolKey calldata key,
        uint256 amount0,
        uint256 amount1,
        bytes calldata hookData
    ) external returns (bytes4) {
        revert NotImplemented();
    }

    function afterDonate(
        address sender,
        PoolKey calldata key,
        uint256 amount0,
        uint256 amount1,
        bytes calldata hookData
    ) external returns (bytes4) {
        revert NotImplemented();
    }

    function _hooksRegistrationBitmapFrom(
        Permissions memory permissions
    ) internal pure returns (uint16) {
        return uint16(
            (
                permissions.beforeInitialize
                    ? 1 << HOOKS_BEFORE_INITIALIZE_OFFSET
                    : 0
            )
                | (
                    permissions.afterInitialize
                        ? 1 << HOOKS_AFTER_INITIALIZE_OFFSET
                        : 0
                )
                | (
                    permissions.beforeAddLiquidity
                        ? 1 << HOOKS_BEFORE_ADD_LIQUIDITY_OFFSET
                        : 0
                )
                | (
                    permissions.afterAddLiquidity
                        ? 1 << HOOKS_AFTER_ADD_LIQUIDITY_OFFSET
                        : 0
                )
                | (
                    permissions.beforeRemoveLiquidity
                        ? 1 << HOOKS_BEFORE_REMOVE_LIQUIDITY_OFFSET
                        : 0
                )
                | (
                    permissions.afterRemoveLiquidity
                        ? 1 << HOOKS_AFTER_REMOVE_LIQUIDITY_OFFSET
                        : 0
                )
                | (
                    permissions.beforeSwap
                        ? 1 << HOOKS_BEFORE_SWAP_OFFSET
                        : 0
                )
                | (
                    permissions.afterSwap
                        ? 1 << HOOKS_AFTER_SWAP_OFFSET
                        : 0
                )
                | (
                    permissions.beforeDonate
                        ? 1 << HOOKS_BEFORE_DONATE_OFFSET
                        : 0
                )
                | (
                    permissions.afterDonate
                        ? 1 << HOOKS_AFTER_DONATE_OFFSET
                        : 0
                )
                | (
                    permissions.befreSwapReturnsDelta
                        ? 1 << HOOKS_BEFORE_SWAP_RETURNS_DELTA_OFFSET
                        : 0
                )
                | (
                    permissions.afterSwapReturnsDelta
                        ? 1 << HOOKS_AFTER_SWAP_RETURNS_DELTA_OFFSET
                        : 0
                )
                | (
                    permissions.afterAddLiquidityReturnsDelta
                        ? 1 << HOOKS_AFTER_ADD_LIQUIDIY_RETURNS_DELTA_OFFSET
                        : 0
                )
                | (
                    permissions.afterRemoveLiquidityReturnsDelta
                        ? 1
                            << HOOKS_AFTER_REMOVE_LIQUIDIY_RETURNS_DELTA_OFFSET
                        : 0
                )
        );
    }
}
