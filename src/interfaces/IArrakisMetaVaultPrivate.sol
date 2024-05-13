// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

interface IArrakisMetaVaultPrivate {
    // #region errors.

    error MintZero();
    error BurnZero();
    error BurnOverflow();
    error DepositorAlreadyWhitelisted();
    error NotAlreadyWhitelistedDepositor();
    error OnlyDepositor();

    // #endregion errors.

    // #region events.

    /// @notice Event describing a deposit done by an user inside this vault.
    /// @param amount0 amount of token0 needed to increase the portfolio of "proportion" percent.
    /// @param amount1 amount of token1 needed to increase the portfolio of "proportion" percent.
    event LogDeposit(uint256 amount0, uint256 amount1);

    /// @notice Event describing a withdrawal of participation by an user inside this vault.
    /// @param proportion percentage of the current position that user want to withdraw.
    /// @param amount0 amount of token0 withdrawn due to withdraw action.
    /// @param amount1 amount of token1 withdrawn due to withdraw action.
    event LogWithdraw(
        uint256 proportion, uint256 amount0, uint256 amount1
    );

    /// @notice Event describing the whitelist of fund depositor.
    /// @param depositors list of address that are granted to depositor role.
    event LogWhitelistDepositors(address[] depositors);

    /// @notice Event describing the blacklist of fund depositor.
    /// @param depositors list of address who depositor role is revoked.
    event LogBlacklistDepositors(address[] depositors);

    // #endregion events.

    /// @notice function used to deposit tokens or expand position inside the
    /// inherent strategy.
    /// @param amount0_ amount of token0 need to increase the position by proportion_;
    /// @param amount1_ amount of token1 need to increase the position by proportion_;
    function deposit(
        uint256 amount0_,
        uint256 amount1_
    ) external payable;

    /// @notice function used to withdraw tokens or position contraction of the
    /// underpin strategy.
    /// @param proportion_ the proportion of position contraction.
    /// @param receiver_ the address that will receive withdrawn tokens.
    /// @return amount0 amount of token0 returned.
    /// @return amount1 amount of token1 returned.
    function withdraw(
        uint256 proportion_,
        address receiver_
    ) external returns (uint256 amount0, uint256 amount1);

    /// @notice function used to whitelist depositors.
    /// @param depositors_ list of address that will be granted to depositor role.
    function whitelistDepositors(address[] calldata depositors_)
        external;

    /// @notice function used to blacklist depositors.
    /// @param depositors_ list of address who depositor role will be revoked.
    function blacklistDepositors(address[] calldata depositors_)
        external;

    /// @notice function used to get the list of depositors.
    /// @return depositors list of address granted to depositor role.
    function depositors() external view returns (address[] memory);
}
