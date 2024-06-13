// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {IPoolManager} from
    "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";

library PoolManagerGetter {
    function currencyDelta(
        IPoolManager poolManager_,
        address owner_,
        Currency currency_
    ) internal view returns (int256 balance) {
        bytes32 slot;

        /// @dev see CurrencyDelta v4 library.
        assembly {
            mstore(0, owner_)
            mstore(32, currency_)
            slot := keccak256(0, 64)
        }

        /// @dev transient storage loading.
        balance = int256(uint256(poolManager_.exttload(slot)));
    }
}
