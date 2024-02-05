// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {console, Test} from "forge-std/Test.sol";

contract ArrakisMetaVaultPublicTest is Test {
    function setUp() public {}

    // -- SETUP AND PERMISSIONED FUNCTIONS ------------------------------------

    // - [ ] constructor
    //     - [ ] storage is properly set
    //     - [ ] reverts on zero address owner
    function test_constructor() public {}
    function testRevert_constructor_addressZero_owner() public {}

    // - [ ] mint
    //     - [ ] mints shares to the receiver
    //     - [ ] calculates the correct proportion
    //     - [ ] calls `deposit()` on the module
    //     - [ ] emits `LogDeposit` event
    //     - [ ] reverts if shares are zero
    //     - [ ] reverts if proportion is zero
    function test_mint() public {}
    function testRevert_deposit_onlyOwnerChecks() public {}
}