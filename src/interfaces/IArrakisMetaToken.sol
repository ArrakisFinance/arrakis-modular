// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

interface IArrakisMetaToken {
    // #region events.

    event LogMint(
        uint256 shares_,
        address receiver_,
        uint256 amount0_,
        uint256 amount1_
    );
    event LogBurn(
        uint256 shares_,
        address receiver_,
        uint256 amount0_,
        uint256 amount1_
    );

    // #endregion events.

    /// @notice function used to mint share of the vault position
    /// @param shares_ amount representing the part of the position owned by receiver.
    /// @param receiver_ address where share token will be sent.
    /// @return amount0 amount of token0 deposited.
    /// @return amount1 amount of token1 deposited.
    function mint(
        uint256 shares_,
        address receiver_
    ) external returns (uint256 amount0, uint256 amount1);

    /// @notice function used to burn share of the vault position.
    /// @param shares_ amount of share that will be burn.
    /// @param receiver_ address where underlying tokens will be sent.
    /// @return amount0 amount of token0 withdrawn.
    /// @return amount1 amount of token1 withdrawn.
    function burn(
        uint256 shares_,
        address receiver_
    ) external returns (uint256 amount0, uint256 amount1);
}
