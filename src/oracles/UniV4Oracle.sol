// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IOracleWrapper} from "../interfaces/IOracleWrapper.sol";
import {IUniV4Oracle} from "../interfaces/IUniV4Oracle.sol";

// #region uniswap v4.

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {
    PoolId,
    PoolIdLibrary
} from "@uniswap/v4-core/src/types/PoolId.sol";
import {IPoolManager} from
    "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {StateLibrary} from
    "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {FullMath} from "@uniswap/v4-core/src/libraries/FullMath.sol";
import {
    Currency,
    CurrencyLibrary
} from "@uniswap/v4-core/src/types/Currency.sol";

// #endregion uniswap v4.

// #region openzeppelin.

import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// #endregion openzeppelin.

contract UniV4Oracle is IOracleWrapper, IUniV4Oracle {
    using StateLibrary for IPoolManager;
    using PoolIdLibrary for PoolKey;

    // #region immutables.

    PoolId public immutable pool;
    address public immutable poolManager;
    uint8 public immutable decimals0;
    uint8 public immutable decimals1;

    // #endregion immutables.

    // #region constructor.
    constructor(PoolKey memory poolKey_, address poolManager_) {
        if (poolManager_ == address(0)) {
            revert AddressZero();
        }

        PoolId _pool = poolKey_.toId();

        (uint160 sqrtPriceX96,,,) =
            IPoolManager(poolManager_).getSlot0(_pool);

        if (sqrtPriceX96 == 0) {
            revert SqrtPriceZero();
        }

        pool = _pool;
        poolManager = poolManager_;

        if (CurrencyLibrary.isAddressZero(poolKey_.currency0)) {
            decimals0 = 18;
        } else {
            decimals0 = IERC20Metadata(
                Currency.unwrap(poolKey_.currency0)
            ).decimals();
        }

        decimals1 = IERC20Metadata(
            Currency.unwrap(poolKey_.currency1)
        ).decimals();
    }
    // #endregion constructor.

    // #region public.
    function getPrice0()
        public
        view
        override
        returns (uint256 price0)
    {
        (uint160 sqrtPriceX96,,,) =
            IPoolManager(poolManager).getSlot0(pool);

        if (sqrtPriceX96 <= type(uint128).max) {
            price0 = FullMath.mulDiv(
                uint256(sqrtPriceX96) * uint256(sqrtPriceX96),
                10 ** decimals0,
                2 ** 192
            );
        } else {
            price0 = FullMath.mulDiv(
                FullMath.mulDiv(
                    uint256(sqrtPriceX96),
                    uint256(sqrtPriceX96),
                    1 << 64
                ),
                10 ** decimals0,
                1 << 128
            );
        }
    }

    function getPrice1()
        public
        view
        override
        returns (uint256 price1)
    {
        (uint160 sqrtPriceX96,,,) =
            IPoolManager(poolManager).getSlot0(pool);

        if (sqrtPriceX96 <= type(uint128).max) {
            price1 = FullMath.mulDiv(
                2 ** 192,
                10 ** decimals1,
                uint256(sqrtPriceX96) * uint256(sqrtPriceX96)
            );
        } else {
            price1 = FullMath.mulDiv(
                1 << 128,
                10 ** decimals1,
                FullMath.mulDiv(
                    uint256(sqrtPriceX96),
                    uint256(sqrtPriceX96),
                    1 << 64
                )
            );
        }
    }
}
