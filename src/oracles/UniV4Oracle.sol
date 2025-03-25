// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IOracleWrapper} from "../interfaces/IOracleWrapper.sol";
import {IUniV4Oracle} from "../interfaces/IUniV4Oracle.sol";

import {IUniV4StandardModule} from
    "../interfaces/IUniV4StandardModule.sol";

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
import {Initializable} from
    "@openzeppelin/contracts/proxy/utils/Initializable.sol";

// #endregion openzeppelin.

contract UniV4Oracle is
    IOracleWrapper,
    IUniV4Oracle,
    Initializable
{
    using StateLibrary for IPoolManager;
    using PoolIdLibrary for PoolKey;

    // #region immutables.

    address public immutable poolManager;
    bool public immutable isInversed;

    // #endregion immutables.

    address public module;
    uint8 public decimals0;
    uint8 public decimals1;

    // #region constructor.
    constructor(address poolManager_, bool isInversed_) {
        if (poolManager_ == address(0)) {
            revert AddressZero();
        }

        poolManager = poolManager_;
        isInversed = isInversed_;
    }
    // #endregion constructor.

    // #region initialize function.

    function initialize(
        address module_
    ) external override initializer {
        if (module_ == address(0)) {
            revert AddressZero();
        }

        PoolKey memory poolKey;
        (poolKey.currency0, poolKey.currency1,,,) =
            IUniV4StandardModule(module_).poolKey();

        module = module_;

        if (CurrencyLibrary.isAddressZero(poolKey.currency0)) {
            decimals0 = 18;
        } else {
            decimals0 = IERC20Metadata(
                Currency.unwrap(poolKey.currency0)
            ).decimals();
        }

        decimals1 = IERC20Metadata(Currency.unwrap(poolKey.currency1))
            .decimals();
    }

    // #endregion initialize function.

    function getPrice0() external view returns (uint256 price0) {
        if (isInversed) {
            price0 = _getPrice1();
        } else {
            price0 = _getPrice0();
        }
    }

    function getPrice1() external view returns (uint256 price1) {
        if (isInversed) {
            price1 = _getPrice0();
        } else {
            price1 = _getPrice1();
        }
    }

    function _getPrice0() internal view returns (uint256 price0) {
        PoolKey memory poolKey;
        (
            poolKey.currency0,
            poolKey.currency1,
            poolKey.fee,
            poolKey.tickSpacing,
            poolKey.hooks
        ) = IUniV4StandardModule(module).poolKey();

        PoolId pool = poolKey.toId();

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

    function _getPrice1() internal view returns (uint256 price1) {
        PoolKey memory poolKey;
        (
            poolKey.currency0,
            poolKey.currency1,
            poolKey.fee,
            poolKey.tickSpacing,
            poolKey.hooks
        ) = IUniV4StandardModule(module).poolKey();

        PoolId pool = poolKey.toId();

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
