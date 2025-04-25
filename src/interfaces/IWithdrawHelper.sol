// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IWithdrawHelper {

    // #region errors.

    /// @notice Error emitted when the withdraw try to
    /// withdraw more than the funds sitting on the vault.
    error InsufficientUnderlying();
    /// @notice Error emitted when the caller is not the safe.
    error Unauthorized();
    /// @notice Error emitted when the withdraw fails.
    error WithdrawErr();
    /// @notice Error emitted when whitelisting safe as depositor fails.
    error WhitelistDepositorErr();
    /// @notice Error emitted when transfering token0 to receiver fails.
    error Transfer0Err();
    /// @notice Error emitted when transfering token1 to receiver fails.
    error Transfer1Err();
    /// @notice Error emitted when approving module to use token0 fails.
    error Approval0Err();
    /// @notice Error emitted when approving module to use token1 fails.
    error Approval1Err();
    /// @notice Error emitted when depositing through the safe fails.
    error DepositErr();

    // #endregion errors.

    // #region functions.

    /// @notice Withdraws the funds from the vault at any ratio.
    /// @param safe_ The address of the safe that owns the vault.
    /// @param vault_ The address of the vault to withdraw the funds from.
    /// @param amount0_ The amount of token0 to withdraw.
    /// @param amount1_ The amount of token1 to withdraw.
    /// @param receiver_ The address that will receive the funds.
    function withdraw(
        address safe_,
        address vault_,
        uint256 amount0_,
        uint256 amount1_,
        address payable receiver_
    ) external;

    // #endregion functions.
}
