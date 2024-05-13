// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console, Test} from "forge-std/Test.sol";

contract ModulePrivateRegistryTest is Test {
    function setUp() public {}

    // -- MODULE DEPLOYMENT FUNCTIONS -----------------------------------------

    // - [ ] createModule
    //     - [ ] deploys a new module
    //     - [ ] emits `LogCreatePrivateModule` event
    //     - [ ] reverts if the vault type is not PRIVATE_TYPE
    //     - [ ] reverts if the vault is zero address
    //     - [ ] reverts if the module is not linked to the vault
    //     - [ ] reverts if the module guardian is not the registry guardian
    function test_createModule() public {}
    function testRevert_createModule_notPrivateType() public {}
    function testRevert_createModule_addressZero() public {}
    function testRevert_createModule_moduleNotLinked() public {}
    function testRevert_createModule_distinctGuardian() public {}
}
