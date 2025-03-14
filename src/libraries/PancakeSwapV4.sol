// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {IPancakeSwapV4StandardModule} from
    "../interfaces/IPancakeSwapV4StandardModule.sol";
import {NATIVE_COIN} from "../constants/CArrakis.sol";

import {PoolKey} from "@pancakeswap/v4-core/src/types/PoolKey.sol";
import {PoolIdLibrary} from
    "@pancakeswap/v4-core/src/types/PoolId.sol";
import {
    BalanceDeltaLibrary,
    BalanceDelta
} from "@pancakeswap/v4-core/src/types/BalanceDelta.sol";
import {Hooks} from "@pancakeswap/v4-core/src/libraries/Hooks.sol";
import {IHooks} from "@pancakeswap/v4-core/src/interfaces/IHooks.sol";
import {Currency} from "@pancakeswap/v4-core/src/types/Currency.sol";
import {PoolId} from "@pancakeswap/v4-core/src/types/PoolId.sol";
import {
    ICLHooks,
    HOOKS_BEFORE_REMOVE_LIQUIDITY_OFFSET,
    HOOKS_AFTER_REMOVE_LIQUIDITY_OFFSET,
    HOOKS_AFTER_ADD_LIQUIDITY_OFFSET
} from "@pancakeswap/v4-core/src/pool-cl/interfaces/ICLHooks.sol";

import {SafeERC20} from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

library PancakeSwapV4 {
    using PoolIdLibrary for PoolKey;
    using BalanceDeltaLibrary for BalanceDelta;
    using SafeERC20 for IERC20Metadata;
    using Address for address payable;
    using Hooks for bytes32;

    function _checkTokens(
        PoolKey memory poolKey_,
        address token0_,
        address token1_,
        bool isInversed_
    ) internal pure {
        if (isInversed_) {
            /// @dev Currency.unwrap(poolKey_.currency1) == address(0) is not possible
            /// @dev because currency0 should be lower currency1.

            if (token0_ == NATIVE_COIN) {
                revert
                    IPancakeSwapV4StandardModule
                    .NativeCoinCannotBeToken1();
            } else if (Currency.unwrap(poolKey_.currency1) != token0_)
            {
                revert IPancakeSwapV4StandardModule.Currency1DtToken0(
                    Currency.unwrap(poolKey_.currency1), token0_
                );
            }

            if (token1_ == NATIVE_COIN) {
                if (Currency.unwrap(poolKey_.currency0) != address(0))
                {
                    revert
                        IPancakeSwapV4StandardModule
                        .Currency0DtToken1(
                        Currency.unwrap(poolKey_.currency0), token1_
                    );
                }
            } else if (Currency.unwrap(poolKey_.currency0) != token1_)
            {
                revert IPancakeSwapV4StandardModule.Currency0DtToken1(
                    Currency.unwrap(poolKey_.currency0), token1_
                );
            }
        } else {
            if (token0_ == NATIVE_COIN) {
                if (Currency.unwrap(poolKey_.currency0) != address(0))
                {
                    revert
                        IPancakeSwapV4StandardModule
                        .Currency0DtToken0(
                        Currency.unwrap(poolKey_.currency0), token0_
                    );
                }
            } else if (Currency.unwrap(poolKey_.currency0) != token0_)
            {
                revert IPancakeSwapV4StandardModule.Currency0DtToken0(
                    Currency.unwrap(poolKey_.currency0), token0_
                );
            }

            if (token1_ == NATIVE_COIN) {
                revert
                    IPancakeSwapV4StandardModule
                    .NativeCoinCannotBeToken1();
            } else if (Currency.unwrap(poolKey_.currency1) != token1_)
            {
                revert IPancakeSwapV4StandardModule.Currency1DtToken1(
                    Currency.unwrap(poolKey_.currency1), token1_
                );
            }
        }
    }

    function _checkPermissions(
        PoolKey memory poolKey_
    ) internal {
        ICLHooks hooks = ICLHooks(address(poolKey_.hooks));
        if (
            poolKey_.parameters.shouldCall(
                HOOKS_BEFORE_REMOVE_LIQUIDITY_OFFSET,
                hooks
            )
                || poolKey_.parameters.shouldCall(
                    HOOKS_AFTER_REMOVE_LIQUIDITY_OFFSET,
                    hooks
                )
                || poolKey_.parameters.shouldCall(
                    HOOKS_AFTER_ADD_LIQUIDITY_OFFSET,
                    hooks
                )
        ) {
            revert
                IPancakeSwapV4StandardModule
                .NoRemoveOrAddLiquidityHooks();
        }
    }
}
