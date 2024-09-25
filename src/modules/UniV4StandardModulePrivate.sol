// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {
    UniV4StandardModule
} from "../abstracts/UniV4StandardModule.sol";
import {IArrakisLPModulePrivate} from "../interfaces/IArrakisLPModulePrivate.sol";

import {IPoolManager} from
    "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {
    Range as PoolRange,
    UnderlyingPayload
} from "../structs/SUniswapV4.sol";
import {UnderlyingV4} from "../libraries/UnderlyingV4.sol";
import {NATIVE_COIN} from "../constants/CArrakis.sol";

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {
    PoolId,
    PoolIdLibrary
} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Position} from "@uniswap/v4-core/src/libraries/Position.sol";
import {
    Currency,
    CurrencyLibrary
} from "@uniswap/v4-core/src/types/Currency.sol";
import {StateLibrary} from
    "@uniswap/v4-core/src/libraries/StateLibrary.sol";

import {FullMath} from "@uniswap/v4-core/src/libraries/FullMath.sol";

import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SafeERC20} from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @notice this module can only set uni v4 pool that have generic hook,
/// that don't require specific action to become liquidity provider.
contract UniV4StandardModulePrivate is
    UniV4StandardModule,
    IArrakisLPModulePrivate
{
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;
    using Address for address payable;
    using SafeERC20 for IERC20Metadata;

    constructor(address poolManager_, address guardian_) UniV4StandardModule(poolManager_, guardian_) {}

    /// @notice deposit function for private vault.
    /// @param depositor_ address that will provide the tokens.
    /// @param amount0_ amount of token0 that depositor want to send to module.
    /// @param amount1_ amount of token1 that depositor want to send to module.
    function fund(
        address depositor_,
        uint256 amount0_,
        uint256 amount1_
    ) 
        external
        payable
        onlyMetaVault
        whenNotPaused
        nonReentrant
    {
        // #region checks.

        if (depositor_ == address(0)) revert AddressZero();

        if (amount0_ == 0 && amount1_ == 0) revert DepositZero();

        // #endregion checks.

        bytes memory data =
            abi.encode(0, abi.encode(depositor_, amount0_, amount1_));

        bytes memory result = poolManager.unlock(data);

        (uint256 amount0, uint256 amount1) = abi.decode(result, (uint256, uint256));

        emit LogFund(depositor_, amount0, amount1);
    }

    /// @notice Called by the pool manager on `msg.sender` when a lock is acquired
    /// @param data_ The data that was passed to the call to lock
    /// @return result data that you want to be returned from the lock call
    function unlockCallback(
        bytes calldata data_
    ) public virtual returns (bytes memory) {
        IPoolManager _poolManager = poolManager;
        if (msg.sender != address(_poolManager)) {
            revert OnlyPoolManager();
        }

        /// @dev use data to do specific action.

        (uint256 action, bytes memory data) =
            abi.decode(data_, (uint256, bytes));

        if (action == 0) {
            (address depositor, uint256 amount0, uint256 amount1) =
                abi.decode(data, (address, uint256, uint256));
            return _fund(_poolManager, depositor, amount0, amount1);
        }
        _unlockCallback(_poolManager, action, data);
    }

    // #region internal functions.

    function _fund(
        IPoolManager poolManager_,
        address depositor_,
        uint256 amount0_,
        uint256 amount1_
    ) internal returns (bytes memory) {
        PoolKey memory _poolKey = poolKey;
        uint256 length = _ranges.length;

        // #region get liquidity for each positions and mint.

        // #endregion get liquidity for each positions and mint.
        {
            // #region get how much left over we have on poolManager and mint.

            if (amount0_ > 0) {
                address _token0 = address(token0);
                Currency currency0;
                if (_token0 == NATIVE_COIN) {
                    currency0 = Currency.wrap(address(0));
                } else {
                    currency0 = Currency.wrap(_token0);
                }

                poolManager_.mint(
                    address(this),
                    CurrencyLibrary.toId(currency0),
                    amount0_
                );

                poolManager_.sync(currency0);
                if (currency0.isAddressZero()) {
                    poolManager_.settle{value: amount0_}();
                    uint256 ethLeftBalance = address(this).balance;
                    if (ethLeftBalance > 0) {
                        payable(depositor_).sendValue(ethLeftBalance);
                    }
                } else {
                    IERC20Metadata(Currency.unwrap(currency0))
                        .safeTransferFrom(
                        depositor_, address(poolManager_), amount0_
                    );
                    poolManager_.settle();
                }
            }

            if (amount1_ > 0) {
                address _token1 = address(token1);
                Currency currency1;
                if (_token1 == NATIVE_COIN) {
                    currency1 = Currency.wrap(address(0));
                } else {
                    currency1 = Currency.wrap(_token1);
                }

                poolManager_.mint(
                    address(this),
                    CurrencyLibrary.toId(currency1),
                    amount1_
                );

                poolManager_.sync(currency1);
                if (currency1.isAddressZero()) {
                    poolManager_.settle{value: amount1_}();
                    uint256 ethLeftBalance = address(this).balance;
                    if (ethLeftBalance > 0) {
                        payable(depositor_).sendValue(ethLeftBalance);
                    }
                } else {
                    IERC20Metadata(Currency.unwrap(currency1))
                        .safeTransferFrom(
                        depositor_, address(poolManager_), amount1_
                    );
                    poolManager_.settle();
                }
            }

            // #endregion get how much left over we have on poolManager and mint.
        }

        return isInversed
            ? abi.encode(amount1_, amount0_)
            : abi.encode(amount0_, amount1_);
    }

    // #endregion internal functions.
}