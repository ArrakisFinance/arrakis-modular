// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IModuleRegistry} from
    "../../../../src/interfaces/IModuleRegistry.sol";

import {BeaconProxy} from
    "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {EnumerableSet} from
    "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract ModuleRegistryMock is IModuleRegistry {
    using EnumerableSet for EnumerableSet.AddressSet;

    address public admin;
    address public guardian;

    // #region internal properties.

    EnumerableSet.AddressSet internal _beacons;

    // #endregion internal properties.

    // #region mocks functions.

    function setAdmin(address admin_) external {
        admin = admin_;
    }

    function setGuardian(address guardian_) external {
        guardian = guardian_;
    }

    // #endregion mocks functions.

    // #region pure/view functions.

    function beacons() external view returns (address[] memory) {
        return _beacons.values();
    }

    function beaconsContains(address beacon_)
        external
        view
        returns (bool isContained)
    {
        return _beacons.contains(beacon_);
    }

    // #endregion pure/view functions.

    // #region state modifying functions.

    function initialize(address factory_) external {}

    function whitelistBeacons(address[] calldata beacons_) external {
        uint256 length = beacons_.length;

        for (uint256 i; i < length; i++) {
            _beacons.add(beacons_[i]);
        }
    }

    function blacklistBeacons(address[] calldata beacons_) external {
        uint256 length = beacons_.length;

        for (uint256 i; i < length; i++) {
            _beacons.remove(beacons_[i]);
        }
    }

    // #endregion state modifying functions.

    function createModule(
        address,
        address beacon_,
        bytes calldata payload_
    ) external returns (address module) {
        bytes32 salt = keccak256(
            abi.encodePacked(tx.origin, block.number, payload_)
        );

        module =
            address(new BeaconProxy{salt: salt}(beacon_, payload_));
    }
}
