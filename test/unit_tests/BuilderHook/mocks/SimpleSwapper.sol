// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "forge-std/Test.sol";

import {IUnlockCallback} from
    "@uniswap/v4-core/src/interfaces/callback/IUnlockCallback.sol";
import {IPoolManager} from
    "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {StateLibrary} from
    "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {TransientStateLibrary} from
    "@uniswap/v4-core/src/libraries/TransientStateLibrary.sol";

import {SafeCast} from
    "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract SimpleSwapper is IUnlockCallback, Test {
    using StateLibrary for IPoolManager;
    using TransientStateLibrary for IPoolManager;

    // #region constants.
    address public constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant WETH =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    // #endregion constants.

    // #region immutables.
    IPoolManager public immutable poolManager;
    // #endregion immutables.

    PoolKey public poolKey;
    bytes public swapData = "";

    constructor(address poolManager_) {
        poolManager = IPoolManager(poolManager_);
    }

    function setPoolKey(PoolKey calldata poolKey_) external {
        poolKey = poolKey_;
    }

    function setSwapData(bytes calldata data_) external {
        swapData = data_;
    }

    function doSwapOne() external {
        poolManager.unlock(abi.encode(1));
    }

    function unlockCallback(bytes calldata data)
        external
        returns (bytes memory)
    {
        uint256 typeOfLockAcquired = abi.decode(data, (uint256));

        // if (typeOfLockAcquired == 0) _lockAcquiredAddPosition();
        if (typeOfLockAcquired == 1) {
            _lockAcquiredSwap();
        }
        if (typeOfLockAcquired == 2) {
            _lockAcquiredSwapBis();
        }
    }

    // #region internal functions.

    function _lockAcquiredSwap() internal {
        IPoolManager.SwapParams memory params = IPoolManager
            .SwapParams({
            zeroForOne: false,
            amountSpecified: 1_000_774_893,
            sqrtPriceLimitX96: TickMath.MAX_SQRT_PRICE / 2
        });
        poolManager.swap(poolKey, params, swapData);

        // #region settle currency.

        int256 currency0BalanceRaw = poolManager.currencyDelta(
            address(this), poolKey.currency0
        );

        uint256 currency0Balance =
            SafeCast.toUint256(currency0BalanceRaw);

        int256 currency1BalanceRaw = poolManager.currencyDelta(
            address(this), poolKey.currency1
        );

        uint256 currency1Balance =
            SafeCast.toUint256(-currency1BalanceRaw);

        if (currency0Balance > 0) {
            poolManager.take(
                poolKey.currency0, address(this), currency0Balance
            );
        }

        if (currency1Balance > 0) {
            poolManager.sync(poolKey.currency1);
            deal(WETH, address(this), currency1Balance);
            IERC20Metadata(WETH).transfer(
                address(poolManager), currency1Balance
            );
            poolManager.settle(poolKey.currency1);
        }

        // #endregion settle currency.
    }

    function _lockAcquiredSwapBis() internal {
        IPoolManager.SwapParams memory params = IPoolManager
            .SwapParams({
            zeroForOne: true,
            amountSpecified: (1 ether) / 1000,
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE * 2
        });
        poolManager.swap(poolKey, params, swapData);

        // #region settle currency.

        int256 currency0BalanceRaw = poolManager.currencyDelta(
            address(this), poolKey.currency0
        );

        uint256 currency0Balance =
            SafeCast.toUint256(-currency0BalanceRaw);

        int256 currency1BalanceRaw = IPoolManager(
            address(poolManager)
        ).currencyDelta(address(this), poolKey.currency1);

        uint256 currency1Balance =
            SafeCast.toUint256(currency1BalanceRaw);

        if (currency1Balance > 0) {
            poolManager.take(
                poolKey.currency1, address(this), currency1Balance
            );
        }

        if (currency0Balance > 0) {
            poolManager.sync(poolKey.currency0);
            deal(USDC, address(this), currency0Balance);
            IERC20Metadata(USDC).transfer(
                address(poolManager), currency0Balance
            );
            poolManager.settle(poolKey.currency0);
        }

        // #endregion settle currency.
    }

    // #endregion internal functions.
}
