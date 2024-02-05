// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {console, Test} from "forge-std/Test.sol";

contract ModuleRegistryTest is Test {
    function setUp() public {}

    // -- SETUP AND PERMISSIONED FUNCTIONS ------------------------------------

    // - [ ] constructor
    //     - [ ] storage is properly set
    //     - [ ] reverts on zero address owner
    //     - [ ] reverts on zero address guardian
    //     - [ ] reverts on zero address admin
    function test_constructor() public {}
    function testRevert_constructor_addressZero_owner() public {}
    function testRevert_constructor_addressZero_guardian() public {}
    function testRevert_constructor_addressZero_admin() public {}

    // - [ ] whitelistBeacons
    //     - [ ] storage is properly updated
    //     - [ ] emits LogWhitelistBeacons event
    //     - [ ] reverts when `msg.sender` is not the owner
    //     - [ ] reverts when a beacon implementation is zero address
    //     - [ ] reverts when a beacon owner is not the admin
    //     - [ ] reverts when a beacon is already whitelisted
    function test_whitelistBeacons() public {}
    function testRevert_whitelistBeacons_notOwner() public {}
    function testRevert_whitelistBeacons_beaconImplementation_addressZero() public {}
    function testRevert_whitelistBeacons_beaconOwner_notAdmin() public {}
    function testRevert_whitelistBeacons_alreadyWhiteListed() public {}

    // - [ ] blacklistBeacons
    //     - [ ] storage is properly updated
    //     - [ ] emits LogWhitelistBeacons event
    //     - [ ] reverts when `msg.sender` is not the owner
    //     - [ ] reverts when a beacon is not whitelisted
    function test_blacklistBeacons() public {}
    function testRevert_blacklistBeacons_notOwner() public {}
    function testRevert_blacklistBeacons_notWhitelisted() public {}

    // -- MODULE DEPLOYMENT FUNCTIONS -----------------------------------------

    // - [ ] _createModule
    //     - [ ] deploys a new module
    //     - [ ] reverts when the module is not linked to the vault
    //     - [ ] reverts when the module guardian is not the registry guardian
    function test_createModule() public {}
    function testRevert_createModule_addressZero() public {}
    function testRevert_createModule_distinctGuardian() public {}
}