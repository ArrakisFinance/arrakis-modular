// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {UniV4StandardModule} from
    "../abstracts/UniV4StandardModule.sol";
import {IUniV4StandardModule} from
    "../interfaces/IUniV4StandardModule.sol";
import {IArrakisLPModulePublic} from
    "../interfaces/IArrakisLPModulePublic.sol";

import {IPoolManager} from
    "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {
    Range as PoolRange,
    UnderlyingPayload,
    Deposit
} from "../structs/SUniswapV4.sol";
import {PIPS, BASE, NATIVE_COIN} from "../constants/CArrakis.sol";
import {UniswapV4} from "../libraries/UniswapV4.sol";

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
import {
    BalanceDeltaLibrary,
    BalanceDelta
} from "@uniswap/v4-core/src/types/BalanceDelta.sol";

import {FullMath} from "@uniswap/v4-core/src/libraries/FullMath.sol";

import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {SafeCast} from
    "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SafeERC20} from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @notice this module can only set uni v4 pool that have generic hook,
/// that don't require specific action to become liquidity provider.
contract UniV4StandardModulePublic is
    UniV4StandardModule,
    IArrakisLPModulePublic
{
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;
    using Address for address payable;
    using SafeERC20 for IERC20Metadata;
    using BalanceDeltaLibrary for BalanceDelta;
    using UniswapV4 for IUniV4StandardModule;

    // #region public constants.

    /// @dev id = keccak256(abi.encode("UniV4StandardModulePublic"))
    bytes32 public constant id =
        0x22f7eb8a1e047f6c492e05813f6e9c6cb1563d057a61278b8e0ae7977af1ac3f;

    // #endregion public constants.

    bool public notFirstDeposit;

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

        bytes memory result = poolManager.unlock(data);

        (amount0, amount1) = abi.decode(result, (uint256, uint256));

        if (poolKey.currency0.isAddressZero()) {
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
            (address depositor, uint256 proportion, uint256 value) =
                abi.decode(data, (address, uint256, uint256));
            bytes memory result;
            (result, notFirstDeposit) = IUniV4StandardModule(
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
        return _unlockCallback(Action(action), data);
    }
}
