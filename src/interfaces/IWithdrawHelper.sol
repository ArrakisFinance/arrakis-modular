// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IWithdrawHelper {

    // #region errors.

    error InsufficientUnderlying();
    error Unauthorized();

    // #endregion errors.

    // #region functions.

    function withdraw(
        address safe_,
        address vault_,
        uint256 amount0_,
        uint256 amount1_,
        address receiver_
    ) external;

    // #endregion functions.
}
