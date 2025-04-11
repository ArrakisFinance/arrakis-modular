// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {IArrakisLPModulePublic} from
    "../interfaces/IArrakisLPModulePublic.sol";
import {PancakeSwapV4StandardModule} from
    "../abstracts/PancakeSwapV4StandardModule.sol";
import {IPancakeSwapV4StandardModule} from
    "../interfaces/IPancakeSwapV4StandardModule.sol";
import {NATIVE_COIN, BASE} from "../constants/CArrakis.sol";
import {PancakeSwapV4} from "../libraries/PancakeSwapV4.sol";
import {Deposit} from "../structs/SPancakeSwapV4.sol";

import {PoolIdLibrary} from
    "@pancakeswap/v4-core/src/types/PoolId.sol";
import {
    Currency,
    CurrencyLibrary
} from "@pancakeswap/v4-core/src/types/Currency.sol";
import {PoolKey} from "@pancakeswap/v4-core/src/types/PoolKey.sol";
import {
    BalanceDelta,
    BalanceDeltaLibrary
} from "@pancakeswap/v4-core/src/types/BalanceDelta.sol";

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {SafeERC20} from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {NATIVE_COIN} from "../constants/CArrakis.sol";

/// @notice this module can only set pancake v4 pool that have generic hook,
/// that don't require specific action to become liquidity provider.
contract PancakeSwapV4StandardModulePublic is
    PancakeSwapV4StandardModule,
    IArrakisLPModulePublic
{
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using Address for address payable;
    using SafeERC20 for IERC20Metadata;
    using BalanceDeltaLibrary for BalanceDelta;
    using PancakeSwapV4 for IPancakeSwapV4StandardModule;

    // #region public constants.

    /// @dev id = keccak256(abi.encode("PancakeSwapV4StandardModulePublic"))
    bytes32 public constant id =
        0xf8a84b2e3e22d069766d4756d362bc5c6eb85d74765bf4feeb8c017f9e8c7937;

    // #endregion public constants.

    bool public notFirstDeposit;

    constructor(
        address poolManager_,
        address guardian_,
        address vault_
    ) PancakeSwapV4StandardModule(poolManager_, guardian_, vault_) {}

    /// @notice function used by metaVault to deposit tokens into the strategy.
    /// @param depositor_ address that will provide the tokens.
    /// @param proportion_ proportion of position needed to be add.
    /// @return amount0 amount of token0 deposited.
    /// @return amount1 amount of token1 deposited.
    function deposit(
        address depositor_,
        uint256 proportion_
    )
        external
        payable
        onlyMetaVault
        nonReentrant
        whenNotPaused
        returns (uint256 amount0, uint256 amount1)
    {
        // #region checks.

        if (depositor_ == address(0)) revert AddressZero();

        if (proportion_ == 0) revert ProportionZero();

        // #endregion checks.

        bytes memory data = abi.encode(
            Action.DEPOSIT_FUND,
            abi.encode(depositor_, proportion_, msg.value)
        );

        bytes memory result = vault.lock(data);

        (amount0, amount1) = abi.decode(result, (uint256, uint256));

        if (poolKey.currency0.isNative()) {
            if (isInversed) {
                if (amount1 > msg.value) {
                    revert InvalidMsgValue();
                } else if (amount1 < msg.value) {
                    payable(depositor_).sendValue(msg.value - amount1);
                }
            } else {
                if (amount0 > msg.value) {
                    revert InvalidMsgValue();
                } else if (amount0 < msg.value) {
                    payable(depositor_).sendValue(msg.value - amount0);
                }
            }
        }

        emit LogDeposit(depositor_, proportion_, amount0, amount1);
    }

    function initializePosition(
        bytes calldata
    ) external override onlyMetaVault {
        IERC20Metadata _token0 = token0;
        IERC20Metadata _token1 = token1;

        uint256 balance0;
        uint256 balance1;

        if (address(_token0) == NATIVE_COIN) {
            balance0 = address(this).balance;
        } else {
            balance0 = _token0.balanceOf(address(this));
        }
        if (address(_token1) == NATIVE_COIN) {
            balance1 = address(this).balance;
        } else {
            balance1 = _token1.balanceOf(address(this));
        }

        if (balance0 > 0 || balance1 > 0) {
            notFirstDeposit = true;
        }
    }

    /// @notice function used by metaVault to withdraw tokens from the strategy.
    /// @param receiver_ address that will receive tokens.
    /// @param proportion_ proportion of position needed to be withdrawn.
    /// @return amount0 amount of token0 withdrawn.
    /// @return amount1 amount of token1 withdrawn.
    function withdraw(
        address receiver_,
        uint256 proportion_
    ) public override returns (uint256 amount0, uint256 amount1) {
        if (proportion_ == BASE) {
            notFirstDeposit = false;
        }
        return super.withdraw(receiver_, proportion_);
    }

    /// @notice Called by the pool manager on `msg.sender` when a lock is acquired
    /// @param data_ The data that was passed to the call to lock
    /// @return result data that you want to be returned from the lock call
    function lockAcquired(
        bytes calldata data_
    ) public virtual returns (bytes memory) {
        if (msg.sender != address(vault)) {
            revert OnlyVault();
        }

        /// @dev use data to do specific action.

        (uint256 action, bytes memory data) =
            abi.decode(data_, (uint256, bytes));

        if (Action(action) == Action.DEPOSIT_FUND) {
            (address depositor, uint256 proportion, uint256 value) =
                abi.decode(data, (address, uint256, uint256));
            bytes memory result;
            (result, notFirstDeposit) = IPancakeSwapV4StandardModule(
                address(this)
            ).deposit(
                Deposit({
                    depositor: depositor,
                    proportion: proportion,
                    value: value,
                    notFirstDeposit: notFirstDeposit,
                    fee0: 0,
                    fee1: 0,
                    leftOverToMint0: 0,
                    leftOverToMint1: 0
                }),
                _ranges
            );
            return result;
        }
        return _lockAcquired(Action(action), data);
    }
}
