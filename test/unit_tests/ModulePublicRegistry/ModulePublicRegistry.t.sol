// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";

import {TestWrapper} from "../../utils/TestWrapper.sol";

// #region mocks.

import {BeaconImplementation} from "./mocks/BeaconImplementation.sol";
import {ArrakisPrivateVaultMock} from "./mocks/ArrakisPrivateVaultMock.sol";
import {ArrakisPublicVaultMock} from "./mocks/ArrakisPublicVaultMock.sol";
import {GuardianMock} from "./mocks/GuardianMock.sol";

// #endregion mocks.

import {ModulePublicRegistry} from "../../../src/ModulePublicRegistry.sol";
import {IModuleRegistry} from "../../../src/interfaces/IModuleRegistry.sol";
import {IModulePublicRegistry} from "../../../src/interfaces/IModulePublicRegistry.sol";
import {BeaconProxyExtended} from "../../../src/proxy/BeaconProxyExtended.sol";

import {Ownable} from "@solady/contracts/auth/Ownable.sol";

import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract ModulePublicRegistryTest is TestWrapper {

    address public owner;
    address public pauser;
    address public admin;

    ModulePublicRegistry public modulePublicRegistry;

    // #region mocks.

    GuardianMock public guardian;

    // #endregion mocks.

    function setUp() public {
        owner = vm.addr(uint256(keccak256(abi.encode("Owner"))));
        pauser = vm.addr(uint256(keccak256(abi.encode("Pauser"))));
        admin = vm.addr(uint256(keccak256(abi.encode("Admin"))));
        guardian = new GuardianMock();

        guardian.setPauser(pauser);
    }

    // #region test constructor.

    function testConstructorOwnerAddressZero() public {
        vm.expectRevert(IModuleRegistry.AddressZero.selector);

        modulePublicRegistry = new ModulePublicRegistry(
            address(0),
            address(guardian),
            admin
        );
    }

    function testConstructorGuardianAddressZero() public {
        vm.expectRevert(IModuleRegistry.AddressZero.selector);

        modulePublicRegistry = new ModulePublicRegistry(
            owner,
            address(0),
            admin
        );
    }

    function testConstructorAdminAddressZero() public {
        vm.expectRevert(IModuleRegistry.AddressZero.selector);

        modulePublicRegistry = new ModulePublicRegistry(
            owner,
            address(guardian),
            address(0)
        );
    }

    function testConstructor() public {
        modulePublicRegistry = new ModulePublicRegistry(
            owner,
            address(guardian),
            admin
        );

        assertEq(owner, modulePublicRegistry.owner());
        assertEq(pauser, modulePublicRegistry.guardian());
        assertEq(admin, modulePublicRegistry.admin());
    }

    // #endregion test constructor.

    // #region test whitelist beacon.

    function testWhitelistBeaconOnlyOwner() public {
        address[] memory beacons = new address[](0);

        modulePublicRegistry = new ModulePublicRegistry(
            owner,
            address(guardian),
            admin
        );

        vm.expectRevert(Ownable.Unauthorized.selector);

        modulePublicRegistry.whitelistBeacons(beacons);
    }

    function testWhitelistBeaconNotBeacon() public {
        address beacon = vm.addr(uint256(keccak256(abi.encode("Beacon"))));
        address[] memory beacons = new address[](1);
        beacons[0] = beacon;

        modulePublicRegistry = new ModulePublicRegistry(
            owner,
            address(guardian),
            admin
        );

        vm.expectRevert(IModuleRegistry.NotBeacon.selector);
        vm.prank(owner);

        modulePublicRegistry.whitelistBeacons(beacons);
    }

    function testWhitelistBeaconNotSameAdmin() public {
        // #region create a upgradeable beacon.

        address beaconAdmin = vm.addr(
            uint256(keccak256(abi.encode("Beacon Address")))
        );
        BeaconImplementation implementation = new BeaconImplementation();

        UpgradeableBeacon beacon = new UpgradeableBeacon(
            address(implementation),
            beaconAdmin
        );

        // #endregion create a upgradeable beacon.

        address[] memory beacons = new address[](1);
        beacons[0] = address(beacon);

        modulePublicRegistry = new ModulePublicRegistry(
            owner,
            address(guardian),
            admin
        );

        vm.expectRevert(IModuleRegistry.NotSameAdmin.selector);
        vm.prank(owner);

        modulePublicRegistry.whitelistBeacons(beacons);
    }

    function testWhitelistBeaconAlreadyWhitelisted() public {
        // #region create a upgradeable beacon.

        address beaconAdmin = vm.addr(
            uint256(keccak256(abi.encode("Beacon Address")))
        );
        BeaconImplementation implementation = new BeaconImplementation();

        UpgradeableBeacon beacon = new UpgradeableBeacon(
            address(implementation),
            admin
        );

        // #endregion create a upgradeable beacon.
        // #region create public module registry.

        modulePublicRegistry = new ModulePublicRegistry(
            owner,
            address(guardian),
            admin
        );

        // #endregion create public module registry.

        address[] memory beacons = new address[](1);
        beacons[0] = address(beacon);

        // #region whitelist beacon.

        vm.prank(owner);

        modulePublicRegistry.whitelistBeacons(beacons);

        // #endregion whitelist beacon.

        vm.expectRevert(
            abi.encodeWithSelector(
                IModuleRegistry.AlreadyWhitelistedBeacon.selector,
                address(beacon)
            )
        );
        vm.prank(owner);

        modulePublicRegistry.whitelistBeacons(beacons);
    }

    function testWhitelistBeacon() public {
        // #region create a upgradeable beacon.

        address beaconAdmin = vm.addr(
            uint256(keccak256(abi.encode("Beacon Address")))
        );
        BeaconImplementation implementation = new BeaconImplementation();

        UpgradeableBeacon beacon = new UpgradeableBeacon(
            address(implementation),
            admin
        );

        // #endregion create a upgradeable beacon.
        // #region create public module registry.

        modulePublicRegistry = new ModulePublicRegistry(
            owner,
            address(guardian),
            admin
        );

        // #endregion create public module registry.

        address[] memory beacons = new address[](1);
        beacons[0] = address(beacon);

        vm.prank(owner);

        modulePublicRegistry.whitelistBeacons(beacons);

        beacons = modulePublicRegistry.beacons();

        assertEq(address(beacon), beacons[0]);
    }

    // #endregion test whitelist beacon.

    // #region test blacklist beacon.

    function testBlacklistBeaconsOnlyOwner() public {
        address notOwner = vm.addr(uint256(keccak256(abi.encode("Not Owner"))));

        vm.prank(notOwner);

        // #region create public module registry.

        modulePublicRegistry = new ModulePublicRegistry(
            owner,
            address(guardian),
            admin
        );

        // #endregion create public module registry.

        address[] memory beacons = new address[](0);

        vm.expectRevert(Ownable.Unauthorized.selector);

        modulePublicRegistry.blacklistBeacons(beacons);
    }

    function testBlacklistBeaconsNotAlreadyWhitelistedBeacon() public {
        // #region create public module registry.

        modulePublicRegistry = new ModulePublicRegistry(
            owner,
            address(guardian),
            admin
        );

        // #endregion create public module registry.

        // #region create a upgradeable beacon.

        address beaconAdmin = vm.addr(
            uint256(keccak256(abi.encode("Beacon Address")))
        );
        BeaconImplementation implementation = new BeaconImplementation();

        UpgradeableBeacon beacon = new UpgradeableBeacon(
            address(implementation),
            admin
        );

        // #endregion create a upgradeable beacon.

        address[] memory beacons = new address[](1);
        beacons[0] = address(beacon);

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                IModuleRegistry.NotAlreadyWhitelistedBeacon.selector,
                address(beacon)
            )
        );

        modulePublicRegistry.blacklistBeacons(beacons);
    }

    function testBlacklistBeacons() public {
        // #region create public module registry.

        modulePublicRegistry = new ModulePublicRegistry(
            owner,
            address(guardian),
            admin
        );

        // #endregion create public module registry.

        // #region create a upgradeable beacon.

        address beaconAdmin = vm.addr(
            uint256(keccak256(abi.encode("Beacon Address")))
        );
        BeaconImplementation implementation = new BeaconImplementation();

        UpgradeableBeacon beacon = new UpgradeableBeacon(
            address(implementation),
            admin
        );

        // #endregion create a upgradeable beacon.

        // #region whitelist beacon.

        address[] memory beacons = new address[](1);
        beacons[0] = address(beacon);

        vm.prank(owner);

        modulePublicRegistry.whitelistBeacons(beacons);

        // #endregion whitelist beacon.

        beacons = modulePublicRegistry.beacons();

        assertEq(address(beacon), beacons[0]);

        vm.prank(owner);

        modulePublicRegistry.blacklistBeacons(beacons);

        beacons = modulePublicRegistry.beacons();

        assertEq(0, beacons.length);
    }

    // #endregion test blacklist beacon.

    // #region test createModule.

    function testCreateModuleOnlyPublicVault() public {
        // #region create public module registry.

        modulePublicRegistry = new ModulePublicRegistry(
            owner,
            address(guardian),
            admin
        );

        // #endregion create public module registry.
        // #region create a private mock vault.

        ArrakisPrivateVaultMock privateVault = new ArrakisPrivateVaultMock();

        // #endregion create a private mock vault.
        // #region create module payload.

        bytes memory payload = abi.encodeWithSelector(
            BeaconImplementation.setGuardianAndMetaVault.selector,
            pauser,
            address(privateVault)
        );

        // #endregion create module payload.
        // #region create a upgradeable beacon.

        address beaconAdmin = vm.addr(
            uint256(keccak256(abi.encode("Beacon Address")))
        );
        BeaconImplementation implementation = new BeaconImplementation();

        UpgradeableBeacon beacon = new UpgradeableBeacon(
            address(implementation),
            admin
        );

        // #endregion create a upgradeable beacon.
        // #region whitelist beacon.

        address[] memory beacons = new address[](1);
        beacons[0] = address(beacon);

        vm.prank(owner);

        modulePublicRegistry.whitelistBeacons(beacons);

        // #endregion whitelist beacon.

        vm.expectRevert(IModulePublicRegistry.NotPublicVault.selector);

        modulePublicRegistry.createModule(
            address(privateVault),
            address(beacon),
            payload
        );
    }

    function testCreateModuleVaultAddressZero() public {
        // #region create public module registry.

        modulePublicRegistry = new ModulePublicRegistry(
            owner,
            address(guardian),
            admin
        );

        // #endregion create public module registry.
        // #region create module payload.

        bytes memory payload = abi.encodeWithSelector(
            BeaconImplementation.setGuardianAndMetaVault.selector,
            pauser,
            address(0)
        );

        // #endregion create module payload.
        // #region create a upgradeable beacon.

        address beaconAdmin = vm.addr(
            uint256(keccak256(abi.encode("Beacon Address")))
        );
        BeaconImplementation implementation = new BeaconImplementation();

        UpgradeableBeacon beacon = new UpgradeableBeacon(
            address(implementation),
            admin
        );

        // #endregion create a upgradeable beacon.

        vm.expectRevert(IModuleRegistry.AddressZero.selector);

        modulePublicRegistry.createModule(address(0), address(beacon), payload);
    }

    function testCreateModuleNotAlreadyWhitelistedBeacon() public {
        // #region create public module registry.

        modulePublicRegistry = new ModulePublicRegistry(
            owner,
            address(guardian),
            admin
        );

        // #endregion create public module registry.
        // #region create a public mock vault.

        ArrakisPublicVaultMock publicVault = new ArrakisPublicVaultMock();

        // #endregion create a public mock vault.
        // #region create module payload.

        bytes memory payload = abi.encodeWithSelector(
            BeaconImplementation.setGuardianAndMetaVault.selector,
            pauser,
            address(publicVault)
        );

        // #endregion create module payload.
        // #region create a upgradeable beacon.

        address beaconAdmin = vm.addr(
            uint256(keccak256(abi.encode("Beacon Address")))
        );
        BeaconImplementation implementation = new BeaconImplementation();

        UpgradeableBeacon beacon = new UpgradeableBeacon(
            address(implementation),
            admin
        );

        // #endregion create a upgradeable beacon.

        vm.expectRevert(IModuleRegistry.NotWhitelistedBeacon.selector);

        modulePublicRegistry.createModule(
            address(publicVault),
            address(beacon),
            payload
        );
    }

    function testCreateModuleMetaVaultNotInputedVault() public {
        // #region create public module registry.

        modulePublicRegistry = new ModulePublicRegistry(
            owner,
            address(guardian),
            admin
        );

        // #endregion create public module registry.
        // #region create a public mock vault.

        ArrakisPublicVaultMock publicVault = new ArrakisPublicVaultMock();

        // #endregion create a public mock vault.
        // #region create module payload.

        bytes memory payload = abi.encodeWithSelector(
            BeaconImplementation.setGuardianAndMetaVault.selector,
            pauser,
            address(0)
        );

        // #endregion create module payload.
        // #region create a upgradeable beacon.

        address beaconAdmin = vm.addr(
            uint256(keccak256(abi.encode("Beacon Address")))
        );
        BeaconImplementation implementation = new BeaconImplementation();

        UpgradeableBeacon beacon = new UpgradeableBeacon(
            address(implementation),
            admin
        );

        // #endregion create a upgradeable beacon.
        // #region whitelist beacon.

        address[] memory beacons = new address[](1);
        beacons[0] = address(beacon);

        vm.prank(owner);

        modulePublicRegistry.whitelistBeacons(beacons);

        // #endregion whitelist beacon.

        vm.expectRevert(IModuleRegistry.ModuleNotLinkedToMetaVault.selector);

        modulePublicRegistry.createModule(
            address(publicVault),
            address(beacon),
            payload
        );
    }

    function testCreateModuleNotSameGuardian() public {
        // #region create public module registry.

        modulePublicRegistry = new ModulePublicRegistry(
            owner,
            address(guardian),
            admin
        );

        // #endregion create public module registry.
        // #region create a public mock vault.

        ArrakisPublicVaultMock publicVault = new ArrakisPublicVaultMock();

        // #endregion create a public mock vault.
        // #region create module payload.

        address anotherPauser = vm.addr(
            uint256(keccak256(abi.encode("Another Pauser")))
        );

        bytes memory payload = abi.encodeWithSelector(
            BeaconImplementation.setGuardianAndMetaVault.selector,
            anotherPauser,
            address(publicVault)
        );

        // #endregion create module payload.
        // #region create a upgradeable beacon.

        address beaconAdmin = vm.addr(
            uint256(keccak256(abi.encode("Beacon Address")))
        );
        BeaconImplementation implementation = new BeaconImplementation();

        UpgradeableBeacon beacon = new UpgradeableBeacon(
            address(implementation),
            admin
        );

        // #endregion create a upgradeable beacon.
        // #region whitelist beacon.

        address[] memory beacons = new address[](1);
        beacons[0] = address(beacon);

        vm.prank(owner);

        modulePublicRegistry.whitelistBeacons(beacons);

        // #endregion whitelist beacon.
        vm.expectRevert(IModuleRegistry.NotSameGuardian.selector);

        modulePublicRegistry.createModule(
            address(publicVault),
            address(beacon),
            payload
        );
    }

    function testCreateModule() public {
        // #region create public module registry.

        modulePublicRegistry = new ModulePublicRegistry(
            owner,
            address(guardian),
            admin
        );

        // #endregion create public module registry.
        // #region create a public mock vault.

        ArrakisPublicVaultMock publicVault = new ArrakisPublicVaultMock();

        // #endregion create a public mock vault.
        // #region create module payload.

        bytes memory payload = abi.encodeWithSelector(
            BeaconImplementation.setGuardianAndMetaVault.selector,
            pauser,
            address(publicVault)
        );

        // #endregion create module payload.
        // #region create a upgradeable beacon.

        address beaconAdmin = vm.addr(
            uint256(keccak256(abi.encode("Beacon Address")))
        );
        BeaconImplementation implementation = new BeaconImplementation();

        UpgradeableBeacon beacon = new UpgradeableBeacon(
            address(implementation),
            admin
        );

        // #endregion create a upgradeable beacon.
        // #region whitelist beacon.

        address[] memory beacons = new address[](1);
        beacons[0] = address(beacon);

        vm.prank(owner);

        modulePublicRegistry.whitelistBeacons(beacons);

        // #endregion whitelist beacon.

        address module = modulePublicRegistry.createModule(
            address(publicVault),
            address(beacon),
            payload
        );

        assertEq(
            BeaconProxyExtended(payable(module)).beacon(),
            address(beacon)
        );
    }

    // #endregion test createModule.
}
