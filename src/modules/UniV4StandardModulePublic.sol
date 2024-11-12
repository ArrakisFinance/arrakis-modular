// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {UniV4StandardModule} from
    "../abstracts/UniV4StandardModule.sol";
import {IArrakisLPModulePublic} from
    "../interfaces/IArrakisLPModulePublic.sol";

import {IPoolManager} from
    "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {
    Range as PoolRange,
    UnderlyingPayload
} from "../structs/SUniswapV4.sol";
import {UnderlyingV4} from "../libraries/UnderlyingV4.sol";
import {PIPS, BASE} from "../constants/CArrakis.sol";

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

    // #region public constants.

    /// @dev id = keccak256(abi.encode("UniV4StandardModulePublic"))
    bytes32 public constant id =
        0x22f7eb8a1e047f6c492e05813f6e9c6cb1563d057a61278b8e0ae7977af1ac3f;

    // #endregion public constants.

    bool public notFirstDeposit;

    constructor(
        address poolManager_,
        address guardian_,
        address cowSwapEthFlow_
    ) UniV4StandardModule(poolManager_, guardian_, cowSwapEthFlow_) {}

    /// @notice function used by metaVault to deposit tokens into the strategy.
    /// @param depositor_ address that will provide the tokens.
    /// @param proportion_ number of share needed to be add.
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
        notFirstDeposit = true;
    }

    /// @notice function used by metaVault to withdraw tokens from the strategy.
    /// @param receiver_ address that will receive tokens.
    /// @param proportion_ number of share needed to be withdrawn.
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
            return _deposit(depositor, proportion, value);
        }
        return _unlockCallback(Action(action), data);
    }

    // #region internal functions.

    function _deposit(
        address depositor_,
        uint256 proportion_,
        uint256 value_
    ) internal returns (bytes memory) {
        PoolKey memory _poolKey = poolKey;
        uint256 length = _ranges.length;

        // #region get liquidity for each positions and mint.

        // #region fees computations.

        {
            uint256 fee0;
            uint256 fee1;
            PoolRange[] memory poolRanges = _getPoolRanges(length);

            {
                (uint256 leftOver0, uint256 leftOver1) =
                    _getLeftOvers(_poolKey);

                (,, fee0, fee1) = UnderlyingV4.totalUnderlyingWithFees(
                    UnderlyingPayload({
                        ranges: poolRanges,
                        poolManager: poolManager,
                        self: address(this),
                        leftOver0: leftOver0,
                        leftOver1: leftOver1
                    })
                );
            }

            {
                // #region send manager fees.

                address manager = metaVault.manager();
                uint256 managerFee0 =
                    FullMath.mulDiv(fee0, managerFeePIPS, PIPS);
                uint256 managerFee1 =
                    FullMath.mulDiv(fee1, managerFeePIPS, PIPS);

                if (managerFee0 > 0) {
                    poolManager.take(
                        _poolKey.currency0, manager, managerFee0
                    );
                }
                if (managerFee1 > 0) {
                    poolManager.take(
                        _poolKey.currency1, manager, managerFee1
                    );
                }

                if (managerFee0 > 0 || managerFee1 > 0) {
                    emit LogWithdrawManagerBalance(
                        manager, managerFee0, managerFee1
                    );
                }

                // #endregion send manager fees.

                // #region mint extra collected fees.

                uint256 extraCollect0 = fee0 - managerFee0;
                uint256 extraCollect1 = fee1 - managerFee1;

                if (extraCollect0 > 0) {
                    poolManager.take(
                        _poolKey.currency0,
                        address(this),
                        extraCollect0
                    );
                }
                if (extraCollect1 > 0) {
                    poolManager.take(
                        _poolKey.currency1,
                        address(this),
                        extraCollect1
                    );
                }

                // #endregion mint extra collected fees.
            }
        }
        {
            // #endregion fees computations.

            PoolId poolId = _poolKey.toId();
            for (uint256 i; i < length; i++) {
                Range memory range = _ranges[i];

                Position.State memory state;

                (
                    state.liquidity,
                    state.feeGrowthInside0LastX128,
                    state.feeGrowthInside1LastX128
                ) = poolManager.getPositionInfo(
                    poolId,
                    address(this),
                    range.tickLower,
                    range.tickUpper,
                    ""
                );

                /// @dev no need to rounding up because uni v4 should do it during minting.
                uint256 liquidity = FullMath.mulDiv(
                    uint256(state.liquidity), proportion_, BASE
                );

                if (liquidity > 0) {
                    poolManager.modifyLiquidity(
                        _poolKey,
                        IPoolManager.ModifyLiquidityParams({
                            tickLower: range.tickLower,
                            tickUpper: range.tickUpper,
                            liquidityDelta: SafeCast.toInt256(liquidity),
                            salt: bytes32(0)
                        }),
                        ""
                    );
                }
            }
        }

        uint256 leftOver0ToMint;
        uint256 leftOver1ToMint;

        // #endregion get liquidity for each positions and mint.
        {
            // #region get how much left over we have on poolManager and mint.

            (uint256 leftOver0, uint256 leftOver1) =
                _getLeftOvers(_poolKey);

            if (_poolKey.currency0.isAddressZero()) {
                leftOver0 = leftOver0 - value_;
            }

            if (!notFirstDeposit) {
                address manager = metaVault.manager();

                if (leftOver0 > 0) {
                    if (_poolKey.currency0.isAddressZero()) {
                        payable(manager).sendValue(leftOver0);
                    } else {
                        IERC20Metadata(
                            Currency.unwrap(_poolKey.currency0)
                        ).safeTransfer(manager, leftOver0);
                    }
                }
                if (leftOver1 > 0) {
                    IERC20Metadata(
                        Currency.unwrap(_poolKey.currency1)
                    ).safeTransfer(manager, leftOver1);
                }

                leftOver0 = _init0;
                leftOver1 = _init1;
                notFirstDeposit = true;
            }

            // rounding up during mint only.
            leftOver0ToMint = FullMath.mulDivRoundingUp(
                leftOver0, proportion_, BASE
            );
            leftOver1ToMint = FullMath.mulDivRoundingUp(
                leftOver1, proportion_, BASE
            );

            if (leftOver0ToMint > 0) {
                if (!_poolKey.currency0.isAddressZero()) {
                    IERC20Metadata(
                        Currency.unwrap(_poolKey.currency0)
                    ).safeTransferFrom(
                        depositor_, address(this), leftOver0ToMint
                    );
                }
            }

            if (leftOver1ToMint > 0) {
                IERC20Metadata(Currency.unwrap(_poolKey.currency1))
                    .safeTransferFrom(
                    depositor_, address(this), leftOver1ToMint
                );
            }

            // #endregion get how much left over we have on poolManager and mint.
        }
        // #region get how much we should settle with poolManager.

        (uint256 amount0, uint256 amount1) = _checkCurrencyBalances();

        // #endregion get how much we should settle with poolManager.

        // #region settle.

        if (amount0 > 0) {
            poolManager.sync(_poolKey.currency0);
            if (_poolKey.currency0.isAddressZero()) {
                /// @dev no need to use Address lib for PoolManager.
                poolManager.settle{value: amount0}();
            } else {
                IERC20Metadata(Currency.unwrap(_poolKey.currency0))
                    .safeTransferFrom(
                    depositor_, address(poolManager), amount0
                );
                poolManager.settle();
            }
        }

        if (amount1 > 0) {
            /// @dev currency1 cannot be native coin because address(0).
            poolManager.sync(_poolKey.currency1);

            IERC20Metadata(Currency.unwrap(_poolKey.currency1))
                .safeTransferFrom(
                depositor_, address(poolManager), amount1
            );
            poolManager.settle();
        }

        // #endregion settle.

        amount0 = amount0 + leftOver0ToMint;
        amount1 = amount1 + leftOver1ToMint;

        return isInversed
            ? abi.encode(amount1, amount0)
            : abi.encode(amount0, amount1);
    }

    // #endregion internal functions.
}
