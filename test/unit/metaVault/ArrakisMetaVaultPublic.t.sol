// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console, Test} from "forge-std/Test.sol";

contract ArrakisMetaVaultPublicTest is Test {
    function setUp() public {}

    // -- SETUP AND PERMISSIONED FUNCTIONS ------------------------------------

    // - [ ] constructor
    //     - [ ] storage is properly set
    //     - [ ] reverts if owner is zero address
    function test_constructor() public {}
    function testRevert_constructor_zeroAddress_owner() public {}

    // -- ERC20 FUNCTIONS ------------------------------------------------------

    // - [ ] mint
    //     - [ ] mints shares to the receiver
    //     - [ ] calculates the correct proportion
    //     - [ ] calls `deposit()` on the module
    //     - [ ] emits `LogDeposit` event
    //     - [ ] emits `LogMint` event
    //     - [ ] reverts if shares are zero
    //     - [ ] reverts if proportion is zero
    //     - [ ] reverts if receiver is zero address
    function test_mint() public {}
    function testRevert_mint_zeroAddress_receiver() public {}
    function testRevert_mint_zeroProportion() public {}
    function testRevert_mint_zeroShares() public {}

    // - [ ] burn
    //     - [ ] burns shares from `msg.sender`
    //     - [ ] calculates the correct proportion
    //     - [ ] calls `withdraw()` on the module
    //     - [ ] emits `LogWithdraw` event
    //     - [ ] emits `LogBurn` event
    //     - [ ] reverts if shares are zero
    //     - [ ] reverts if proportion is zero
    //     - [ ] reverts if shares is greater than supply
    //     - [ ] reverts if receiver is zero address
    function test_burn() public {}
    function testRevert_burn_zeroAddress_receiver() public {}
    function testRevert_burn_zeroProportion() public {}
    function testRevert_burn_zeroShares() public {}
    function testRevert_burn_sharesGtSupply() public {}

    // -- GETTER FUNCTIONS ----------------------------------------------------

    // - [ ] name
    //     - [ ] returns the name
    function test_name() public {}

    // - [ ] symbol
    //     - [ ] returns the symbol
    function test_symbol() public {}

    // - [ ] vaultType
    //     - [ ] returns PUBLIC_TYPE
    function test_vaultType() public {}

    // -- UNIMPLEMENTED FUNCTIONS ---------------------------------------------

    // - [ ] transferOwnership
    //     - [ ] always reverts
    function testRevert_transferOwnership() public {}

    // - [ ] renounceOwnership
    //     - [ ] always reverts
    function testRevert_renounceOwnership() public {}

    // - [ ] completeOwnershipHandover
    //     - [ ] always reverts
    function testRevert_completeOwnershipHandover() public {}
}
