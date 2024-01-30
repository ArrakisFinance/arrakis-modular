// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IArrakisLPPublicModule {
    // #region events.

    /// @notice Event describing a deposit done by an user inside this module.
    /// @dev deposit action can be indexed by depositor.
    /// @param depositor address of the tokens provider.
    /// @param proportion percentage of the current position that depositor want to increase.
    /// @param amount0 amount of token0 needed to increase the portfolio of "proportion" percent.
    /// @param amount1 amount of token1 needed to increase the portfolio of "proportion" percent.
    event LogDeposit(
        address indexed depositor,
        uint256 proportion,
        uint256 amount0,
        uint256 amount1
    );

    // #endregion events.

    // #region functions.

    /// @notice function used by metaVault to deposit tokens into the strategy.
    /// @param depositor_ address that will provide the tokens.
    /// @param proportion_ number of share needed to be add.
    /// @return amount0 amount of token0 deposited.
    /// @return amount1 amount of token1 deposited.
    function deposit(
        address depositor_,
        uint256 proportion_
    ) external payable returns (uint256 amount0, uint256 amount1);

    // #endregion functions.
}
