// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IArrakisLPPrivateModule {
    // #region events.

    /// @notice Event describing a fund done by an user inside this module.
    /// @dev fund action can be indexed by depositor.
    /// @param depositor address of the tokens provider.
    /// @param amount0 amount of token0 needed to increase the portfolio of "proportion" percent.
    /// @param amount1 amount of token1 needed to increase the portfolio of "proportion" percent.
    event LogFund(
        address indexed depositor,
        uint256 amount0,
        uint256 amount1
    );

    // #endregion events.

    // #region functions.

    /// @notice function used by metaVault to deposit tokens into the strategy.
    /// @param depositor_ address that will provide the tokens.
    /// @param amount0_ number of token0 to fund the module.
    /// @param amount1_ number of token1 to fund the module.
    function fund(
        address depositor_,
        uint256 amount0_,
        uint256 amount1_
    ) external payable;

    // #endregion functions.
}
