// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

import {TestWrapper} from "../../utils/TestWrapper.sol";

// #region mocks.

import {GuardianMock} from "./mocks/GuardianMock.sol";
import {ArrakisPublicVaultMock} from
    "./mocks/ArrakisPublicVaultMock.sol";
import {ArrakisPrivateVaultMock} from
    "./mocks/ArrakisPrivateVaultMock.sol";
import {BeaconImplementation} from "./mocks/BeaconImplementation.sol";
import {ArrakisMetaVaultFactoryMock} from
    "./mocks/ArrakisMetaVaultFactoryMock.sol";

// #endregion mocks.

import {ModulePrivateRegistry} from
    "../../../src/ModulePrivateRegistry.sol";
import {IModulePrivateRegistry} from
    "../../../src/interfaces/IModulePrivateRegistry.sol";

import {UpgradeableBeacon} from
    "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract ModulePrivateRegistryTest is TestWrapper {
    address public owner;
    address public pauser;
    address public admin;

    ModulePrivateRegistry public modulePrivateRegistry;
    ArrakisMetaVaultFactoryMock public factory;

    // #region mocks.

    GuardianMock public guardian;

    // #endregion mocks.

    function setUp() public {
        owner = vm.addr(uint256(keccak256(abi.encode("Owner"))));
        pauser = vm.addr(uint256(keccak256(abi.encode("Pauser"))));
        admin = vm.addr(uint256(keccak256(abi.encode("Admin"))));
        guardian = new GuardianMock();
        factory = new ArrakisMetaVaultFactoryMock();

        guardian.setPauser(pauser);

        modulePrivateRegistry =
            new ModulePrivateRegistry(owner, address(guardian), admin);

        modulePrivateRegistry.initialize(address(factory));
    }

    // #region test create module for private vault.

    function testCreateModuleForOnlyPrivateVault() public {
        // #region create a public mock vault.

        ArrakisPublicVaultMock publicVault =
            new ArrakisPublicVaultMock();

        // #endregion create a public mock vault.

        // #region create module payload.

        bytes memory payload = abi.encodeWithSelector(
            BeaconImplementation.setGuardianAndMetaVault.selector,
            address(publicVault),
            pauser
        );

        // #endregion create module payload.
        // #region create a upgradeable beacon.

        address beaconAdmin =
            vm.addr(uint256(keccak256(abi.encode("Beacon Address"))));
        BeaconImplementation implementation =
            new BeaconImplementation();

        UpgradeableBeacon beacon =
            new UpgradeableBeacon(address(implementation));

        beacon.transferOwnership(admin);

        // #endregion create a upgradeable beacon.
        // #region whitelist beacon.

        address[] memory beacons = new address[](1);
        beacons[0] = address(beacon);

        vm.prank(owner);

        modulePrivateRegistry.whitelistBeacons(beacons);

        // #endregion whitelist beacon.

        vm.expectRevert(
            IModulePrivateRegistry.NotPrivateVault.selector
        );

        modulePrivateRegistry.createModule(
            address(publicVault), address(beacon), payload
        );
    }

    function testCreateModule() public {
        // #region create a private mock vault.

        ArrakisPrivateVaultMock privateVault =
            new ArrakisPrivateVaultMock();

        // #endregion create a private mock vault.

        // #region create module payload.

        bytes memory payload = abi.encodeWithSelector(
            BeaconImplementation.setGuardianAndMetaVault.selector,
            pauser,
            address(privateVault)
        );

        // #endregion create module payload.
        // #region create a upgradeable beacon.

        address beaconAdmin =
            vm.addr(uint256(keccak256(abi.encode("Beacon Address"))));
        BeaconImplementation implementation =
            new BeaconImplementation();

        UpgradeableBeacon beacon =
            new UpgradeableBeacon(address(implementation));

        beacon.transferOwnership(admin);

        // #endregion create a upgradeable beacon.
        // #region whitelist beacon.

        address[] memory beacons = new address[](1);
        beacons[0] = address(beacon);

        vm.prank(owner);

        modulePrivateRegistry.whitelistBeacons(beacons);

        // #endregion whitelist beacon.
        // #region add vault into the factory.

        factory.addPrivateVault(address(privateVault));

        // #endregion add vault into the factory.

        modulePrivateRegistry.createModule(
            address(privateVault), address(beacon), payload
        );
    }

    // #endregion test create module for private vault.
}
