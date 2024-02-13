// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IModuleRegistry} from "../interfaces/IModuleRegistry.sol";
import {IArrakisLPModule} from "../interfaces/IArrakisLPModule.sol";
import {IGuardian} from "../interfaces/IGuardian.sol";
import {BeaconProxyExtended} from "../proxy/BeaconProxyExtended.sol";

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IBeacon} from "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";

import {Ownable} from "@solady/contracts/auth/Ownable.sol";

abstract contract ModuleRegistry is IModuleRegistry, Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    // #region public properties.

    /// @dev should be a timelock contract.
    address public admin;

    // #endregion public properties.

    // #region internal properties.

    EnumerableSet.AddressSet internal _beacons;
    address internal _guardian;

    // #endregion internal properties.

    constructor(address owner_, address guardian_, address admin_) {
        if (
            owner_ == address(0) ||
            guardian_ == address(0) ||
            admin_ == address(0)
        ) revert AddressZero();

        _initializeOwner(owner_);
        _guardian = guardian_;
        admin = admin_;
    }

    // #region public view functions.

    /// @notice function to get the whitelisted list of IBeacon
    /// that have module as implementation.
    /// @return beacons list of upgradeable beacon.
    function beacons() external view returns (address[] memory) {
        return _beacons.values();
    }

    /// @notice function to know if the beacons enumerableSet contain
    /// beacon_
    /// @param beacon_ beacon address to check
    /// @param isContained is true if beacon_ is whitelisted.
    function beaconsContains(
        address beacon_
    ) external view returns (bool isContained) {
        return _beacons.contains(beacon_);
    }

    /// @notice function used to get the guardian address of arrakis protocol.
    /// @return guardian address of the pauser.
    function guardian() external view returns (address) {
        return IGuardian(_guardian).pauser();
    }

    // #endregion public view functions.

    // #region public state modifying functions.

    /// @notice function used to whitelist IBeacon  that contain
    /// implementation of valid module.
    /// @param beacons_ list of beacon to whitelist.
    function whitelistBeacons(address[] calldata beacons_) external onlyOwner {
        uint256 length = beacons_.length;

        for (uint256 i; i < length; i++) {
            address beacon = beacons_[i];

            // #region checks.

            if(beacon.code.length == 0) revert NotBeacon();

            if (Ownable(beacon).owner() != admin) revert NotSameAdmin();

            if (_beacons.contains(beacon))
                revert AlreadyWhitelistedBeacon(beacon);

            // #endregion checks.

            // #region effects.

            _beacons.add(beacon);

            // #endregion effects.
        }

        // #region events.

        emit LogWhitelistBeacons(beacons_);

        // #endregion events.
    }

    /// @notice function used to blacklist IBeacon that contain
    /// implementation of unvalid (from now) module.
    /// @param beacons_ list of beacon to blacklist.
    function blacklistBeacons(address[] calldata beacons_) external onlyOwner {
        uint256 length = beacons_.length;

        for (uint256 i; i < length; i++) {
            address beacon = beacons_[i];

            // #region checks.

            if (!_beacons.contains(beacon))
                revert NotAlreadyWhitelistedBeacon(beacon);

            // #endregion checks.

            // #region effects.

            _beacons.remove(beacon);

            // #endregion effects.
        }

        // #region events.

        emit LogBlacklistBeacons(beacons_);

        // #endregion events.
    }

    // #endregion public state modifying functions.

    // #region internal state modifying functions.

    function _createModule(
        address vault_,
        address beacon_,
        bytes calldata payload_
    ) internal returns (address module) {
        // #region checks.

        if (!_beacons.contains(beacon_)) revert NotWhitelistedBeacon();

        // #endregion checks.

        // #region interactions.

        bytes32 salt = keccak256(
            abi.encodePacked(tx.origin, block.number, payload_)
        );

        module = address(
            new BeaconProxyExtended{salt: salt}(beacon_, payload_)
        );

        // #endregion interactions.

        // #region assertions.

        if (vault_ != address(IArrakisLPModule(module).metaVault()))
            revert ModuleNotLinkedToMetaVault();

        if (
            IGuardian(_guardian).pauser() != IArrakisLPModule(module).guardian()
        ) revert NotSameGuardian();

        // #endregion assertions.
    }

    function _checkVaultNotAddressZero(address vault_) internal {
        if (vault_ == address(0)) revert AddressZero();
    }

    // #endregion internal state modifying functions.
}
