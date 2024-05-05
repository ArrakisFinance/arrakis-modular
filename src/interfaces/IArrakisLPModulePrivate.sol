// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

/// @notice expose a deposit function for that can
/// deposit any share of token0 and token1.
/// @dev this deposit feature will be used by
/// private actor.
interface IArrakisLPModulePrivate {
    // #region errors.

    error DepositZero();

    // #endregion errors.

    // #region events.

    /// @notice event emitted when owner of private fund the private vault.
    /// @param depositor address that are sending the tokens, the owner.
    /// @param amount0 amount of token0 sent by depositor.
    /// @param amount1 amount of token1 sent by depositor.
    event LogFund(
        address depositor, uint256 amount0, uint256 amount1
    );

    // #endregion events.

    /// @notice deposit function for private vault.
    /// @param depositor_ address that will provide the tokens.
    /// @param amount0_ amount of token0 that depositor want to send to module.
    /// @param amount1_ amount of token1 that depositor want to send to module.
    function fund(
        address depositor_,
        uint256 amount0_,
        uint256 amount1_
    ) external payable;
}
