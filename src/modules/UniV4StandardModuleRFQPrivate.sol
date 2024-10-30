// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {UniV4StandardModuleRFQ} from
    "../abstracts/UniV4StandardModuleRFQ.sol";
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
/// and can use is left over for rfq.
contract UniV4StandardModuleRFQPrivate is
    UniV4StandardModuleRFQ,
    IArrakisLPModulePrivate
{
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using Address for address payable;
    using SafeERC20 for IERC20Metadata;

    /// @dev id = keccak256(abi.encode("UniV4StandardModuleRFQPrivate"))
    bytes32 public constant id =
        0xd317c9fb3bb799edd5a682eb238b339a5777fe7d1fa37c6aa468f53005ac9876;

    constructor(
        address poolManager_,
        address guardian_
    ) UniV4StandardModuleRFQ(poolManager_, guardian_) {}

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

        if (depositor_ == address(0)) revert AddressZero();

        if (amount0_ == 0 && amount1_ == 0) revert DepositZero();

        // #endregion checks.

        bytes memory data = abi.encode(
            Action.DEPOSIT_FUND,
            abi.encode(depositor_, amount0_, amount1_)
        );

        bytes memory result = poolManager.unlock(data);

        (uint256 amount0, uint256 amount1) =
            abi.decode(result, (uint256, uint256));

        if(poolKey.currency0.isAddressZero()) {
            if(isInversed) {
                if(amount1 != msg.value) {
                    revert("Invalid msg.value");
                }
            } else {
                if(amount0 != msg.value) {
                    revert("Invalid msg.value");
                }
            }
        }

        emit LogFund(depositor_, amount0, amount1);
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

        if (Action(action) == Action.DEPOSIT_FUND) {
            (address depositor, uint256 amount0, uint256 amount1) =
                abi.decode(data, (address, uint256, uint256));
            return _fund(depositor, amount0, amount1);
        }

        return _unlockCallback(Action(action), data);
    }

    // #region internal functions.

    function _fund(
        address depositor_,
        uint256 amount0_,
        uint256 amount1_
    ) internal returns (bytes memory) {
        // #region get liquidity for each positions and mint.

        // #endregion get liquidity for each positions and mint.
        {
            // #region get how much left over we have on poolManager and mint.

            if (amount0_ > 0) {
                if(address(token0) != NATIVE_COIN) {
                    token0.safeTransferFrom(
                        depositor_, address(this), amount0_
                    );
                }
            }

            if (amount1_ > 0) {
                if(address(token1) != NATIVE_COIN) {
                    token1.safeTransferFrom(
                        depositor_, address(this), amount1_
                    );
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