// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {IPoolManager} from
    "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {
    PoolIdLibrary,
    PoolId
} from "@uniswap/v4-core/src/types/PoolId.sol";
import {
    Slot0, Slot0Library
} from "@uniswap/v4-core/src/types/Slot0.sol";
import {Pool} from "@uniswap/v4-core/src/libraries/Pool.sol";
import {Position} from "@uniswap/v4-core/src/libraries/Position.sol";

import {PoolGetters} from
    "@uniswap/v4-periphery/contracts/libraries/PoolGetters.sol";

import {SafeCast} from
    "@openzeppelin/contracts/utils/math/SafeCast.sol";

/// @dev getters not exposed by PoolGetters of v4-periphery.
library PoolGetterExt {
    using PoolIdLibrary for PoolId;
    using Slot0Library for Slot0;

    // #region constants.

    uint256 constant POOL_SLOT = 6;
    uint256 constant FEEGROWTH_OFFSET = 1;
    uint256 constant LIQUIDITY_OFFSET = 3;
    uint256 constant POSITION_OFFSET = 6;

    // #endregion constants.

    // #region public functions.

    // #region Slot0.

    function slot0(
        IPoolManager poolManager_,
        PoolId poolId_
    ) internal view returns (Slot0) {
        return Slot0.wrap(
            poolManager_.extsload(
                keccak256(abi.encode(poolId_, POOL_SLOT))
            )
        );
    }

    function sqrtPriceX96(
        IPoolManager poolManager_,
        PoolId poolId_
    ) internal view returns (uint160) {
        Slot0 s = Slot0.wrap(
            poolManager_.extsload(
                keccak256(abi.encode(poolId_, POOL_SLOT))
            )
        );

        return s.sqrtPriceX96();
    }

    function tick(
        IPoolManager poolManager_,
        PoolId poolId_
    ) internal view returns (int24) {
        Slot0 s = Slot0.wrap(
            poolManager_.extsload(
                keccak256(abi.encode(poolId_, POOL_SLOT))
            )
        );

        return s.tick();
    }

    function protocolFee(
        IPoolManager poolManager_,
        PoolId poolId_
    ) internal view returns (uint24) {
        Slot0 s = Slot0.wrap(
            poolManager_.extsload(
                keccak256(abi.encode(poolId_, POOL_SLOT))
            )
        );

        return s.protocolFee();
    }

    function lpFee(
        IPoolManager poolManager_,
        PoolId poolId_
    ) internal view returns (uint24) {
        Slot0 s = Slot0.wrap(
            poolManager_.extsload(
                keccak256(abi.encode(poolId_, POOL_SLOT))
            )
        );

        return s.protocolFee();
    }

    // #endregion Slot0.

    function feeGrowthGlobalX128(
        IPoolManager poolManager_,
        PoolId poolId_
    )
        internal
        view
        returns (
            uint256 feeGrowthGlobal0X128,
            uint256 feeGrowthGlobal1X128
        )
    {
        bytes memory s = poolManager_.extsload(
            bytes32(
                uint256(keccak256(abi.encode(poolId_, POOL_SLOT)))
                    + FEEGROWTH_OFFSET
            ),
            2
        );

        (feeGrowthGlobal0X128, feeGrowthGlobal1X128) =
            abi.decode(s, (uint256, uint256));
    }

    function liquidity(
        IPoolManager poolManager_,
        PoolId poolId_
    ) internal view returns (uint128) {
        bytes32 s = poolManager_.extsload(
            bytes32(
                uint256(keccak256(abi.encode(poolId_, POOL_SLOT)))
                    + LIQUIDITY_OFFSET
            )
        );

        return SafeCast.toUint128(uint256(s));
    }

    function tickInfo(
        IPoolManager poolManager_,
        PoolId poolId_,
        int24 tick_
    ) internal view returns (Pool.TickInfo memory) {
        bytes memory s = poolManager_.extsload(
            keccak256(
                abi.encode(
                    tick_,
                    uint256(keccak256(abi.encode(poolId_, POOL_SLOT)))
                        + PoolGetters.TICKS_OFFSET
                )
            ),
            3
        );

        (
            uint128 liquidityGross,
            int128 liquidityNet,
            uint256 feeGrowthOutside0X128,
            uint256 feeGrowthOutside1X128
        ) = abi.decode(s, (uint128, int128, uint256, uint256));

        return Pool.TickInfo(
            liquidityGross,
            liquidityNet,
            feeGrowthOutside0X128,
            feeGrowthOutside1X128
        );
    }

    function getLiquidity(
        IPoolManager poolManager_,
        PoolId poolId_,
        address owner_,
        int24 lowerTick_,
        int24 upperTick_
    ) internal view returns (uint128) {
        bytes32 positionKey = keccak256(
            abi.encodePacked(
                owner_, lowerTick_, upperTick_, bytes32(0)
            )
        );

        bytes32 s = poolManager_.extsload(
            keccak256(
                abi.encode(
                    positionKey,
                    uint256(keccak256(abi.encode(poolId_, POOL_SLOT)))
                        + POSITION_OFFSET
                )
            )
        );

        return SafeCast.toUint128(uint256(s));
    }

    function position(
        IPoolManager poolManager_,
        PoolId poolId_,
        address owner_,
        int24 lowerTick_,
        int24 upperTick_
    ) internal view returns (Position.Info memory) {
        bytes32 positionKey = keccak256(
            abi.encodePacked(
                owner_, lowerTick_, upperTick_, bytes32(0)
            )
        );

        bytes memory s = poolManager_.extsload(
            keccak256(
                abi.encode(
                    positionKey,
                    uint256(keccak256(abi.encode(poolId_, POOL_SLOT)))
                        + POSITION_OFFSET
                )
            ),
            3
        );

        (
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128
        ) = abi.decode(s, (uint128, uint256, uint256));

        return Position.Info(
            liquidity,
            feeGrowthInside0LastX128,
            feeGrowthInside1LastX128
        );
    }

    // #endregion public functions.
}
