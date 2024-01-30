// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IModuleRegistry} from "../interfaces/IModuleRegistry.sol";
import {IArrakisLPModule} from "../interfaces/IArrakisLPModule.sol";

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IBeacon} from "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";

import {Ownable} from "@solady/contracts/auth/Ownable.sol";

abstract contract ModuleRegistry is IModuleRegistry, Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    // #region internal properties.

    EnumerableSet.AddressSet internal _beacons;

    // #endregion internal properties.

    constructor(address owner_) {
        if (owner_ == address(0)) revert AddressZero();

        _initializeOwner(owner_);
    }

    // #region public view functions.

    function beacons() external view returns (address[] memory) {
        return _beacons.values();
    }

    // #endregion public view functions.

    // #region public state modifying functions.

    function whitelistBeacons(address[] calldata beacons_) external onlyOwner {
        uint256 length = beacons_.length;

        for (uint256 i; i < length; i++) {
            address beacon = beacons_[i];

            // #region checks.

            try IBeacon(beacon).implementation() returns (address impl) {
                if (impl == address(0)) revert ImplementationIsAddressZero();
            } catch {
                revert NotBeacon();
            }

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

    function _createModule(address vault_,
        address beacon_,
        bytes calldata payload_
    ) internal returns (address module) {
        // #region checks.

        if (!_beacons.contains(beacon_)) revert NotWhitelistedBeacon();
        if (vault_ == address(0)) revert AddressZero();

        // #endregion checks.

        // #region interactions.

        bytes32 salt = keccak256(
            abi.encodePacked(tx.origin, block.number, payload_)
        );

        module = address(new BeaconProxy{salt: salt}(beacon_, payload_));

        // #endregion interactions.

        // #region assertions.

        if (vault_ != address(IArrakisLPModule(module).metaVault()))
            revert ModuleNotLinkedToMetaVault();

        // #endregion assertions.
    }

    // #endregion internal state modifying functions.
}
