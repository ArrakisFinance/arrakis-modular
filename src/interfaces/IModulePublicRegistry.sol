// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

interface IModulePublicRegistry {
    // #region errors.

    error NotPublicVault();

    // #endregion errors.

    // #region events.

    /// @notice Log creation of a public module.
    /// @param beacon which beacon from who we get the implementation.
    /// @param payload payload sent to the module constructor.
    /// @param vault address of the Arrakis Meta Vault that
    /// will own this module
    /// @param creator address that create the module.
    /// @param module address of the newly created module.
    event LogCreatePublicModule(
        address beacon,
        bytes payload,
        address vault,
        address creator,
        address module
    );

    // #endregion events.
}
