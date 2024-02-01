// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @notice expose a deposit function for that can
/// deposit a specific share of token0 and token1.
/// @dev this deposit feature will be used by public actor.
interface IArrakisLPModulePublic {
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
    ) external returns (uint256 amount0, uint256 amount1);
}
