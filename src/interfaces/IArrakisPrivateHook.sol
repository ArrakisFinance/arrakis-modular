// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";

interface IArrakisPrivateHook {
    // #region errors.

    error AddressZero();
    error OnlyModule();
    error NotImplemented();
    error OnlyVaultExecutor();

    // #endregion errors.

    // #region events.

    event SetFee(uint24 fee);

    // #endregion events.

    function setFee(
        PoolKey calldata poolKey_,
        uint24 fee_
    ) external;

    // #region view functions.

    function module() external view returns (address);
    function vault() external view returns (address);
    function manager() external view returns (address);
    function fee() external view returns (uint24);
    function poolManager() external view returns (address);

    // #endregion view functions.
}
