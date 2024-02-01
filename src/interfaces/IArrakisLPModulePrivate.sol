// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @notice expose a deposit function for that can
/// deposit any share of token0 and token1.
/// @dev this deposit feature will be used by
/// private actor.
interface IArrakisLPModulePrivate {
    /// @notice deposit function for private vault.
    /// @param depositor_ address that will provide the tokens.
    /// @param amount0_ amount of token0 that depositor want to send to module.
    /// @param amount1_ amount of token1 that depositor want to send to module.
    function fund(
        address depositor_,
        uint256 amount0_,
        uint256 amount1_
    ) external;
}
