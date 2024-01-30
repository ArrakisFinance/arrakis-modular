// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @title IModuleRegistry
/// @author Arrakis Team.
/// @notice interface of module registry that contains all whitelisted modules.
interface IModuleRegistry {
    // #region errors.

    error AddressZero();
    error AlreadyWhitelistedBeacon(address beacon);
    error NotAlreadyWhitelistedBeacon(address beacon);
    error NotWhitelistedBeacon();
    error ImplementationIsAddressZero();
    error NotBeacon();
    error ModuleNotLinkedToMetaVault();

    // #endregion errors.

    // #region events.

    /// @notice Log whitelist action of beacons.
    /// @param beacons list of beacons whitelisted.
    event LogWhitelistBeacons(address[] beacons);
    /// @notice Log blacklist action of beacons.
    /// @param beacons list of beacons blacklisted.
    event LogBlacklistBeacons(address[] beacons);

    // #endregion events.

    // #region view functions.

    /// @notice function to get the whitelisted list of IBeacon
    /// that have module as implementation.
    /// @return beacons list of upgradeable beacon.
    function beacons() external view returns (address[] memory beacons);

    // #endregion view functions.

    // #region state modifying functions.

    /// @notice function used to whitelist IBeacon  that contain
    /// implementation of valid module.
    /// @param beacons_ list of beacon to whitelist.
    function whitelistBeacons(address[] calldata beacons_) external;

    /// @notice function used to blacklist IBeacon that contain
    /// implementation of unvalid (from now) module.
    /// @param beacons_ list of beacon to blacklist.
    function blacklistBeacons(address[] calldata beacons_) external;

    /// @notice function used to create module instance that can be
    /// whitelisted as module inside a vault.
    /// @param beacon_ which whitelisted beacon's implementation we want to
    /// create an instance of.
    /// @param payload_ payload to create the module.
    function createModule(
        address vault_,
        address beacon_,
        bytes calldata payload_
    ) external returns (address module);

    // #endregion state modifying functions.
}
