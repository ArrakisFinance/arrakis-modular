// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IBunkerModule {
    // #region errors.

    error NotImplemented();
    error AmountsZeros();

    // #endregion errors.

    // #region functions.

    /// @notice initialize function to delegate call onced the beacon proxy is deployed,
    /// for initializing the bunker module.
    /// @param metaVault_ address of the meta vault
    function initialize(address metaVault_) external;

    // #endregion functions.
}
