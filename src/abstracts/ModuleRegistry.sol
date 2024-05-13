// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {IModuleRegistry} from "../interfaces/IModuleRegistry.sol";
import {IArrakisMetaVaultFactory} from
    "../interfaces/IArrakisMetaVaultFactory.sol";
import {IArrakisLPModule} from "../interfaces/IArrakisLPModule.sol";
import {IGuardian} from "../interfaces/IGuardian.sol";

import {EnumerableSet} from
    "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Initializable} from
    "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {BeaconProxy} from
    "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

import {Ownable} from "@solady/contracts/auth/Ownable.sol";

abstract contract ModuleRegistry is
    IModuleRegistry,
    Ownable,
    Initializable
{
    using EnumerableSet for EnumerableSet.AddressSet;

    // #region public properties.

    IArrakisMetaVaultFactory public factory;
    /// @dev should be a timelock contract.
    address public admin;

    // #endregion public properties.

    // #region internal immutables.

    address internal immutable _guardian;

    // #endregion internal immutables.

    // #region internal properties.

    EnumerableSet.AddressSet internal _beacons;

    // #endregion internal properties.

    constructor(address owner_, address guardian_, address admin_) {
        if (
            owner_ == address(0) || guardian_ == address(0)
                || admin_ == address(0)
        ) {
            revert AddressZero();
        }
        _initializeOwner(owner_);
        _guardian = guardian_;
        admin = admin_;
    }

    // #region initialize.

    /// @dev function used to initialize module registry.
    /// @param factory_ address of ArrakisMetaVaultFactory,
    ///  who is the only one who can call the init management function.
    function initialize(address factory_) external initializer {
        if (factory_ == address(0)) {
            revert AddressZero();
        }

        factory = IArrakisMetaVaultFactory(factory_);
    }

    // #endregion initialize.

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
    function beaconsContains(address beacon_)
        external
        view
        returns (bool isContained)
    {
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
    function whitelistBeacons(address[] calldata beacons_)
        external
        onlyOwner
    {
        uint256 length = beacons_.length;

        for (uint256 i; i < length; i++) {
            address beacon = beacons_[i];

            // #region checks.

            if (beacon.code.length == 0) revert NotBeacon();

            if (
                Ownable(beacon).owner() != admin
                    && Ownable(beacon).owner() != address(0)
            ) revert NotSameAdmin();

            if (_beacons.contains(beacon)) {
                revert AlreadyWhitelistedBeacon(beacon);
            }

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
    function blacklistBeacons(address[] calldata beacons_)
        external
        onlyOwner
    {
        uint256 length = beacons_.length;

        for (uint256 i; i < length; i++) {
            address beacon = beacons_[i];

            // #region checks.

            if (!_beacons.contains(beacon)) {
                revert NotAlreadyWhitelistedBeacon(beacon);
            }

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

        if (!_beacons.contains(beacon_)) {
            revert NotWhitelistedBeacon();
        }

        // #endregion checks.

        // #region interactions.

        bytes32 salt = keccak256(
            abi.encodePacked(tx.origin, block.number, payload_)
        );

        module =
            address(new BeaconProxy{salt: salt}(beacon_, payload_));

        // #endregion interactions.

        // #region assertions.

        if (vault_ != address(IArrakisLPModule(module).metaVault())) {
            revert ModuleNotLinkedToMetaVault();
        }

        if (
            IGuardian(_guardian).pauser()
                != IArrakisLPModule(module).guardian()
        ) revert NotSameGuardian();

        // #endregion assertions.
    }

    function _checkVaultNotAddressZero(address vault_)
        internal
        pure
    {
        if (vault_ == address(0)) revert AddressZero();
    }

    // #endregion internal state modifying functions.
}
