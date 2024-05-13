// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

interface IManager {
    // #region external view functions.

    /// @notice function used to know the selector of initManagement functions.
    /// @param selector bytes4 defining the init management selector.
    function getInitManagementSelector()
        external
        pure
        returns (bytes4 selector);

    /// @notice function used to know if a vault is under management by this manager.
    /// @param vault_ address of the meta vault the caller want to check.
    /// @return isManaged boolean which is true if the vault is under management, false otherwise.
    function isManaged(address vault_)
        external
        view
        returns (bool isManaged);

    // #endregion external view functions.
}
