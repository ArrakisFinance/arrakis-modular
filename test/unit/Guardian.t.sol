// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console, Test} from "forge-std/Test.sol";

contract GuardianTest is Test {
    function setUp() public {}

    // -- SETUP AND PERMISSIONED FUNCTIONS ------------------------------------

    // - [ ] constructor
    //     - [ ] storage is properly set
    //     - [ ] reverts if owner is zero address
    //     - [ ] reverts if pauser is zero address
    function test_constructor() public {}
    function testRevert_constructor_zeroAddress_owner() public {}
    function testRevert_constructor_zeroAddress_pauser() public {}

    // - [ ] setPauser
    //     - [ ] storage is properly updated
    //     - [ ] emits `LogSetPauser` event
    //     - [ ] reverts if `msg.sender` is not the owner
    //     - [ ] reverts if new pauser is zero address
    function test_setPauser() public {}
    function testRevert_setPauser_notOwner() public {}
    function testRevert_setPauser_zeroAddress_pauser() public {}
}
