// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface INativeManager {
    // #region events.

    event LogWhitelistVaults(address[] vaults);
    event LogBlacklistVaults(address[] vaults);

    // #endregion events.

    // #region functions.

    /// @notice function used to add vault under management.
    /// @param vaults_ list of vault address to add.
    function whitelistVaults(address[] calldata vaults_) external;

    /// @notice function used to remove vault under management.
    /// @param vaults_ list of vault address to remove.
    function blacklistVaults(address[] calldata vaults_) external;

    // #endregion functions.
}
