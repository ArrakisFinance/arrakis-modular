// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {
    UniV4StandardModule,
    UnderlyingPayload,
    PoolRange,
    UnderlyingV4,
    CurrencyLibrary,
    FullMath,
    SafeCast
} from "./UniV4StandardModule.sol";
import {MINIMUM_LIQUIDITY, PIPS} from "../constants/CArrakis.sol";
import {IUniV4UpdatePrice} from "../interfaces/IUniV4UpdatePrice.sol";

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {
    PoolId,
    PoolIdLibrary
} from "@uniswap/v4-core/src/types/PoolId.sol";
import {IPoolManager} from
    "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {StateLibrary} from
    "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {
    Slot0, Slot0Library
} from "@uniswap/v4-core/src/types/Slot0.sol";

import {LiquidityAmounts} from
    "@uniswap/v4-periphery/contracts/libraries/LiquidityAmounts.sol";

contract UniV4UpdatePrice is
    UniV4StandardModule,
    IUniV4UpdatePrice
{
    using StateLibrary for IPoolManager;
    using Slot0Library for Slot0;
    using PoolIdLibrary for PoolKey;

    constructor(
        address poolManager_,
        PoolKey memory poolKey_,
        address metaVault_,
        address token0_,
        address token1_,
        uint256 init0_,
        uint256 init1_,
        address guardian_,
        bool isInversed_
    )
        UniV4StandardModule(
            poolManager_,
            poolKey_,
            metaVault_,
            token0_,
            token1_,
            init0_,
            init1_,
            guardian_,
            isInversed_
        )
    {}

    // #region functions

    function movePrice(
        IPoolManager.SwapParams calldata params_,
        LiquidityRange[] calldata liquidityRanges_
    ) external returns (bytes memory result) {
        bytes memory data =
            abi.encode(3, abi.encode(params_, liquidityRanges_));

        bytes memory result = poolManager.unlock(data);

        (
            uint256 amount0Minted,
            uint256 amount1Minted,
            uint256 amount0Burned,
            uint256 amount1Burned,
            ,
        ) = abi.decode(
            result,
            (uint256, uint256, uint256, uint256, uint256, uint256)
        );

        emit LogRebalance(
            liquidityRanges_,
            amount0Minted,
            amount1Minted,
            amount0Burned,
            amount1Burned
        );
    }

    /// @notice Called by the pool manager on `msg.sender` when a lock is acquired
    /// @param data_ The data that was passed to the call to lock
    /// @return result data that you want to be returned from the lock call
    function unlockCallback(bytes calldata data_)
        external
        override
        returns (bytes memory result)
    {
        if (msg.sender != address(poolManager)) {
            revert OnlyPoolManager();
        }

        /// @dev use data to do specific action.

        (uint256 action, bytes memory data) =
            abi.decode(data_, (uint256, bytes));

        if (action == 0) {
            (address depositor, uint256 proportion) =
                abi.decode(data, (address, uint256));
            result = _deposit(depositor, proportion);
        }
        if (action == 1) {
            (address receiver, uint256 proportion) =
                abi.decode(data, (address, uint256));
            result = _withdraw(receiver, proportion);
        }
        if (action == 2) {
            LiquidityRange[] memory liquidityRanges =
                abi.decode(data, (LiquidityRange[]));
            result = _rebalance(liquidityRanges);
        }

        if (action == 3) {
            (
                IPoolManager.SwapParams memory params,
                LiquidityRange[] memory liquidityRanges
            ) = abi.decode(
                data, (IPoolManager.SwapParams, LiquidityRange[])
            );

            result = _movePrice(params, liquidityRanges);
        }
    }

    // #endregion functions

    // #region view functions.

    function getPositionKey(
        address owner_,
        int24 tickLower_,
        int24 tickUpper_,
        bytes32 salt_
    ) public view returns (bytes32) {
        // positionKey = keccak256(abi.encodePacked(owner, tickLower, tickUpper, salt))
        bytes32 positionKey;

        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x26, salt_) // [0x26, 0x46)
            mstore(0x06, tickUpper_) // [0x23, 0x26)
            mstore(0x03, tickLower_) // [0x20, 0x23)
            mstore(0, owner_) // [0x0c, 0x20)
            positionKey := keccak256(0x0c, 0x3a) // len is 58 bytes
            mstore(0x26, 0) // rewrite 0x26 to 0
        }

        return positionKey;
    }

    // #endregion view functions.

    // #region internal functions.

    function _movePrice(
        IPoolManager.SwapParams memory params_,
        LiquidityRange[] memory liquidityRanges_
    ) internal returns (bytes memory result) {
        PoolKey memory _poolKey = poolKey;
        PoolId poolId = _poolKey.toId();

        uint256 amount0Minted;
        uint256 amount1Minted;
        uint256 amount0Burned;
        uint256 amount1Burned;
        uint256 managerFee0;
        uint256 managerFee1;

        // #region get current price.

        (uint160 oldSqrtPrice,,,) = poolManager.getSlot0(poolId);

        // #endregion get current price.

        // #region fees computations.

        {
            uint256 fee0;
            uint256 fee1;
            PoolRange[] memory ranges = _getPoolRanges(_ranges.length);

            (,, fee0, fee1) = UnderlyingV4.totalUnderlyingWithFees(
                UnderlyingPayload({
                    ranges: ranges,
                    poolManager: poolManager,
                    token0: address(token0),
                    token1: address(token1),
                    self: address(this)
                })
            );

            managerFee0 = FullMath.mulDiv(fee0, managerFeePIPS, PIPS);
            managerFee1 = FullMath.mulDiv(fee1, managerFeePIPS, PIPS);
        }

        // #endregion fees computations.
        // #region remove all liquidities.

        {
            Range[] memory _r = _ranges;

            for (uint256 i; i < _r.length; i++) {
                Range memory range = _r[i];
                uint128 liquidity;
                {
                    bytes32 positionId = getPositionKey(
                        address(this),
                        range.tickLower,
                        range.tickUpper,
                        ""
                    );
                    liquidity = poolManager.getPositionLiquidity(
                        poolId, positionId
                    );
                }
                if (liquidity > 0) {
                    (uint256 amt0, uint256 amt1) = _removeLiquidity(
                        _poolKey,
                        poolId,
                        liquidity,
                        range.tickLower,
                        range.tickUpper
                    );

                    amount0Burned += amt0;
                    amount1Burned += amt1;
                } else {
                    _collectFee(
                        _poolKey,
                        poolId,
                        range.tickLower,
                        range.tickUpper
                    );
                }
            }
        }

        // #endregion remove all liquidities.
        // #region put a bit of liquidity on full range.
        _addLiquidity(
            _poolKey,
            poolId,
            MINIMUM_LIQUIDITY,
            TickMath.MIN_TICK,
            TickMath.MAX_TICK
        );
        // #endregion put a bit of liquidity on full range.
        // #region do swap for moving the price.

        poolManager.swap(_poolKey, params_, "");

        // #endregion do swap for moving the price.
        // #region remove full range liquidity.

        _removeLiquidity(
            _poolKey,
            poolId,
            MINIMUM_LIQUIDITY,
            TickMath.MIN_TICK,
            TickMath.MAX_TICK
        );

        // #endregion remove full range liquidity.
        // #region put back the liquidity on ranges.

        {
            uint256 l = liquidityRanges_.length;
            for (uint256 i; i < l; i++) {
                LiquidityRange memory range = liquidityRanges_[i];

                if (range.liquidity < 0) {
                    revert LiquidityToAddIsNegative();
                }

                (uint256 amt0, uint256 amt1) = _addLiquidity(
                    _poolKey,
                    poolId,
                    SafeCast.toUint128(
                        SafeCast.toUint256(range.liquidity)
                    ),
                    range.range.tickLower,
                    range.range.tickUpper
                );

                amount0Minted += amt0;
                amount1Minted += amt1;
            }
        }

        // #endregion put back the liquidity on ranges.

        // #region collect and send fees to manager.

        {
            address manager = metaVault.manager();
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
        }

        // #endregion collect and send fees to manager.
        // #region mint left over if needed.

        {
            // #region get how much left over we have on poolManager and mint.

            (uint256 amt0, uint256 amt1) = _checkCurrencyBalances();

            if (amt0 > 0) {
                poolManager.mint(
                    address(this),
                    CurrencyLibrary.toId(poolKey.currency0),
                    amt0
                );
            }
            if (amt1 > 0) {
                poolManager.mint(
                    address(this),
                    CurrencyLibrary.toId(poolKey.currency1),
                    amt1
                );
            }

            // #endregion get how much left over we have on poolManager and mint.
        }

        (uint160 newSqrtPrice,,,) = poolManager.getSlot0(poolId);

        emit LogMovePrice(oldSqrtPrice, newSqrtPrice);

        // #endregion mint left over if needed.

        result = abi.encode(
            amount0Minted,
            amount1Minted,
            amount0Burned,
            amount1Burned,
            managerFee0,
            managerFee1
        );
    }

    // #endregion internal functions.
}
