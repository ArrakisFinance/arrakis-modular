// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console, Test} from "forge-std/Test.sol";

contract ModuleRegistryTest is Test {
    function setUp() public {}

    // -- SETUP AND PERMISSIONED FUNCTIONS ------------------------------------

    // - [ ] constructor
    //     - [ ] storage is properly set
    //     - [ ] reverts if owner is zero address
    //     - [ ] reverts if guardian is zero address
    //     - [ ] reverts if admin is zero address
    function test_constructor() public {}
    function testRevert_constructor_zeroAddress_owner() public {}
    function testRevert_constructor_zeroAddress_guardian() public {}
    function testRevert_constructor_zeroAddress_admin() public {}

    // - [ ] whitelistBeacons
    //     - [ ] storage is properly updated
    //     - [ ] emits `LogWhitelistBeacons` event
    //     - [ ] reverts if `msg.sender` is not the owner
    //     - [ ] reverts if a beacon implementation is zero address
    //     - [ ] reverts if a beacon owner is not the admin
    //     - [ ] reverts if a beacon is already whitelisted
    function test_whitelistBeacons() public {}
    function testRevert_whitelistBeacons_notOwner() public {}
    function testRevert_whitelistBeacons_beaconImplementation_addressZero(
    ) public {}
    function testRevert_whitelistBeacons_beaconOwner_notAdmin()
        public
    {}
    function testRevert_whitelistBeacons_alreadyWhiteListed()
        public
    {}

    // - [ ] blacklistBeacons
    //     - [ ] storage is properly updated
    //     - [ ] emits `LogWhitelistBeacons` event
    //     - [ ] reverts if `msg.sender` is not the owner
    //     - [ ] reverts if a beacon is not whitelisted
    function test_blacklistBeacons() public {}
    function testRevert_blacklistBeacons_notOwner() public {}
    function testRevert_blacklistBeacons_notWhitelisted() public {}

    // -- GETTER FUNCTIONS ----------------------------------------------------

    // - [ ] beacons
    //     - [ ] returns all beacon addresses
    function test_beacons() public {}

    // - [ ] beaconsContains
    //     - [ ] whether a beacon is in the registry
    function test_beaconsContains() public {}

    // - [ ] guardian
    //     - [ ] calls `pauser()` on the guardian
    function test_guardian() public {}
}
