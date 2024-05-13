// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {ModuleRegistry} from "./abstracts/ModuleRegistry.sol";
import {IModulePrivateRegistry} from
    "./interfaces/IModulePrivateRegistry.sol";

contract ModulePrivateRegistry is
    ModuleRegistry,
    IModulePrivateRegistry
{
    constructor(
        address owner_,
        address guardian_,
        address admin_
    ) ModuleRegistry(owner_, guardian_, admin_) {}

    // #region public state modifying functions.

    /// @notice function used to create module instance that can be
    /// whitelisted as module inside a vault.
    /// @param beacon_ which whitelisted beacon's implementation we want to
    /// create an instance of.
    /// @param payload_ payload to create the module.
    function createModule(
        address vault_,
        address beacon_,
        bytes calldata payload_
    ) external returns (address module) {
        _checkVaultNotAddressZero(vault_);
        if (!factory.isPrivateVault(vault_)) {
            revert NotPrivateVault();
        }

        module = _createModule(vault_, beacon_, payload_);

        emit LogCreatePrivateModule(
            beacon_, payload_, vault_, msg.sender, module
        );
    }

    // #endregion public state modifying functions.
}
