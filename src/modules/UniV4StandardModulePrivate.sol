// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {UniV4StandardModule} from
    "../abstracts/UniV4StandardModule.sol";
import {IArrakisLPModulePrivate} from
    "../interfaces/IArrakisLPModulePrivate.sol";

import {IPoolManager} from
    "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {NATIVE_COIN} from "../constants/CArrakis.sol";

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {
    Currency,
    CurrencyLibrary
} from "@uniswap/v4-core/src/types/Currency.sol";

import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
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
    using Address for address payable;
    using SafeERC20 for IERC20Metadata;

    // #region public constants.

    /// @dev id = keccak256(abi.encode("UniV4StandardModulePrivate"))
    bytes32 public constant id =
        0xae9c8e22b1f7ab201e144775cd6f848c3c1b0a82315571de8c67ce32ca9a7d44;

    // #endregion public constants.

    constructor(
        address poolManager_,
        address guardian_,
        address distributor_,
        address collector_
    )
        UniV4StandardModule(
            poolManager_,
            guardian_,
            distributor_,
            collector_
        )
    {}

    /// @notice fund function for private vault.
    /// @param depositor_ address that will provide the tokens.
    /// @param amount0_ amount of token0 that depositor want to send to module.
    /// @param amount1_ amount of token1 that depositor want to send to module.
    function fund(
        address depositor_,
        uint256 amount0_,
        uint256 amount1_
    ) external payable onlyMetaVault whenNotPaused nonReentrant {
        // #region checks.

        if (amount0_ == 0 && amount1_ == 0) revert DepositZero();

        if (poolKey.currency0.isAddressZero()) {
            if (isInversed) {
                if (amount1_ > msg.value) {
                    revert InvalidMsgValue();
                } else if (amount1_ < msg.value) {
                    payable(depositor_).sendValue(
                        msg.value - amount1_
                    );
                }
            } else {
                if (amount0_ > msg.value) {
                    revert InvalidMsgValue();
                } else if (amount0_ < msg.value) {
                    payable(depositor_).sendValue(
                        msg.value - amount0_
                    );
                }
            }
        }

        // #endregion checks.

        _fund(depositor_, amount0_, amount1_);

        emit LogFund(depositor_, amount0_, amount1_);
    }

    /// @notice Called by the pool manager on `msg.sender` when a lock is acquired
    /// @param data_ The data that was passed to the call to lock
    /// @return result data that you want to be returned from the lock call
    function unlockCallback(
        bytes calldata data_
    ) public virtual returns (bytes memory) {
        if (msg.sender != address(poolManager)) {
            revert OnlyPoolManager();
        }

        /// @dev use data to do specific action.

        (uint256 action, bytes memory data) =
            abi.decode(data_, (uint256, bytes));

        return _unlockCallback(Action(action), data);
    }

    // #region internal functions.

    function _fund(
        address depositor_,
        uint256 amount0_,
        uint256 amount1_
    ) internal {
        // #region get liquidity for each positions and mint.

        // #endregion get liquidity for each positions and mint.
        {
            // #region get how much left over we have on poolManager and mint.

            if (amount0_ > 0) {
                if (address(token0) != NATIVE_COIN) {
                    token0.safeTransferFrom(
                        depositor_, address(this), amount0_
                    );
                }
            }

            if (amount1_ > 0) {
                if (address(token1) != NATIVE_COIN) {
                    token1.safeTransferFrom(
                        depositor_, address(this), amount1_
                    );
                }
            }

            // #endregion get how much left over we have on poolManager and mint.
        }
    }

    // #endregion internal functions.
}
