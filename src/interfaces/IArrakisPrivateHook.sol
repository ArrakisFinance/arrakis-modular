// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";

interface IArrakisPrivateHook {
    // #region errors.

    error AddressZero();
    error OnlyModule();
    error NotImplemented();
    error OnlyVaultManager();

    // #endregion errors.

    // #region events.

    event SetFee(uint24 fee);

    // #endregion events.

    function setFee(PoolKey calldata poolKey_, uint24 fee_) external;

    // #region view functions.

    function module() external view returns (address);

    // #endregion view functions.
}