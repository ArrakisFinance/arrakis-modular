// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {IPoolManager} from
    "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {BalanceDelta} from
    "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta} from
    "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";

contract SimpleHook is IHooks {
    // #region errors.

    error NotImplemented();

    // #endregion errors.

    function beforeInitialize(
        address sender,
        PoolKey calldata key,
        uint160 sqrtPriceX96,
        bytes calldata hookData
    ) external returns (bytes4) {
        revert NotImplemented();
    }

    function afterInitialize(
        address sender,
        PoolKey calldata key,
        uint160 sqrtPriceX96,
        int24 tick,
        bytes calldata hookData
    ) external returns (bytes4) {
        revert NotImplemented();
    }

    function beforeAddLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external returns (bytes4) {
        revert NotImplemented();
    }

    function afterAddLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta,
        bytes calldata hookData
    ) external returns (bytes4, BalanceDelta) {
        revert NotImplemented();
    }

    function beforeRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external returns (bytes4) {
        return IHooks.beforeRemoveLiquidity.selector;
    }

    function afterRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta,
        bytes calldata hookData
    ) external returns (bytes4, BalanceDelta) {
        revert NotImplemented();
    }

    function beforeSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        bytes calldata hookData
    ) external returns (bytes4, BeforeSwapDelta, uint24) {
        revert NotImplemented();
    }

    function afterSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
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
}
