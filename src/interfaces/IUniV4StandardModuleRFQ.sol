// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IUniV4StandardModuleRFQ {
    // #region errors.

    error OnlyMetaVaultOwner();

    // #endregion errors.

    // #region events.

    event LogApproval(
        address indexed spender,
        uint256 amount0,
        uint256 amount1
    );

    // #endregion events.

    // #region vault owner functions.

    function approve(
        address spender_,
        uint256 amount0_,
        uint256 amount1_
    ) external;

    // #endregion vault owner functions.
}