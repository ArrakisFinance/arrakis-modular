// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

/// @notice expose a deposit function for that can
/// deposit a specific share of token0 and token1.
/// @dev this deposit feature will be used by public actor.
interface IArrakisLPModulePublic {
    // #region events.

    /// @notice Event describing a deposit done by an user inside this module.
    /// @dev deposit action can be indexed by depositor.
    /// @param depositor address of the tokens provider.
    /// @param proportion percentage of the current position that depositor want to increase.
    /// @param amount0 amount of token0 needed to increase the portfolio of "proportion" percent.
    /// @param amount1 amount of token1 needed to increase the portfolio of "proportion" percent.
    event LogDeposit(
        address depositor,
        uint256 proportion,
        uint256 amount0,
        uint256 amount1
    );

    // #endregion events.

    /// @notice deposit function for public vault.
    /// @param depositor_ address that will provide the tokens.
    /// @param proportion_ percentage of portfolio position vault want to expand.
    /// @return amount0 amount of token0 needed to expand the portfolio by "proportion"
    /// percent.
    /// @return amount1 amount of token1 needed to expand the portfolio by "proportion"
    /// percent.
    function deposit(
        address depositor_,
        uint256 proportion_
    ) external payable returns (uint256 amount0, uint256 amount1);
}
