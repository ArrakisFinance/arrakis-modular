// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console, Test} from "forge-std/Test.sol";

contract ArrakisMetaVaultPrivateTest is Test {
    function setUp() public {}

    // -- SETUP AND PERMISSIONED FUNCTIONS ------------------------------------

    // - [ ] constructor
    //     - [ ] NFT is properly set in storage
    function test_constructor() public {}

    // - [ ] deposit
    //     - [ ] calls `fund()` on the module
    //     - [ ] emits `LogDeposit` event
    //     - [ ] reverts if `msg.sender` is not the owner of the NFT
    function test_deposit() public {}
    function testRevert_deposit_onlyOwnerChecks() public {}

    // - [ ] withdraw
    //     - [ ] calls `fund()` on the module
    //     - [ ] calls `withdraw()` on the module
    //     - [ ] calls `withdrawManagerBalance()` on the module
    //     - [ ] emits `LogWithdraw` event
    //     - [ ] emits `LogWithdrawManagerBalance` event
    //     - [ ] reverts if `msg.sender` is not the owner of the NFT
    function test_withdraw() public {}
    function testRevert_withdraw_onlyOwnerChecks() public {}

    // -- GETTER FUNCTIONS ----------------------------------------------------

    // - [ ] vaultType
    //     - [ ] returns PRIVATE_TYPE
    function test_vaultType() public {}
}
