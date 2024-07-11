// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

interface IUniV4UpdatePrice {
    // #region errors.

    error LiquidityToAddIsNegative();
    error NoPermission();

    // #endregion errors.

    // #region events.

    event LogMovePrice(uint160 oldSqrtPrice, uint160 newSqrtPrice);

    // #endregion events.

    // #region functions.

    // #endregion functions.
}
