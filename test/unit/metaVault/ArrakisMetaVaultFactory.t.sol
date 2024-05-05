// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console, Test} from "forge-std/Test.sol";

contract ArrakisMetaVaultFactoryTest is Test {
    function setUp() public {}

    // -- SETUP AND PERMISSIONED FUNCTIONS ------------------------------------

    // - [ ] constructor
    //     - [ ] storage is properly set
    //     - [ ] reverts if owner is zero address
    //     - [ ] reverts if manager is zero address
    //     - [ ] reverts if moduleRegistry is zero addressPublic
    //     - [ ] reverts if moduleRegistry is zero addressPrivate
    function test_constructor() public {}
    function testRevert_constructor_zeroAddress_owner() public {}
    function testRevert_constructor_zeroAddress_manager() public {}
    function testRevert_constructor_zeroAddress_publicRegistry()
        public
    {}
    function testRevert_constructor_zeroAddress_privateRegistry()
        public
    {}

    // - [ ] pause
    //     - [ ] contract is paused
    //     - [ ] emits `pause` event
    //     - [ ] reverts if `msg.sender` is not the owner
    function test_pause() public {}
    function testRevert_pause_notOwner() public {}

    // - [ ] unpause
    //     - [ ] contract is unpaused
    //     - [ ] emits `unpause` event
    //     - [ ] reverts if `msg.sender` is not the owner
    function test_unpause() public {}
    function testRevert_unpause_notOwner() public {}

    // -- VAULT DEPLOYMENT FUNCTIONS ------------------------------------------

    // - [ ] deployPublicVault
    //     - [ ] `owner_` is set as a timelock proposer and executor
    //     - [ ] deploys a new timelock
    //     - [ ] deploys a new vault where timelock is the owner
    //     - [ ] deploys a new module from the public registry
    //     - [ ] adds vault to public vaults set
    //     - [ ] initializes the vault
    //     - [ ] initializes the vault's management on the manager
    //     - [ ] emits `LogPublicVaultCreation` event
    //     - [ ] reverts if paused
    //     - [ ] reverts if `msg.sender` is not a deployer
    //     - [ ] reverts if the management initialization fails
    function test_deployPublicVault() public {}
    function testRevert_deployPublicVault_paused() public {}
    function testRevert_deployPublicVault_notDeployer() public {}
    function testRevert_deployPublicVault_initManagementFails()
        public
    {}

    // - [ ] deployPrivateVault
    //     - [ ] deploys a new vault where the PALM NFT is the owner
    //     - [ ] mints a new PALM NFT for the owner
    //     - [ ] deploys a new module from the private registry
    //     - [ ] adds vault to private vaults set
    //     - [ ] initializes the vault
    //     - [ ] initializes the vault's management on the manager
    //     - [ ] emits `LogPrivateVaultCreation` event
    //     - [ ] reverts if paused
    //     - [ ] reverts if the management initialization fails
    function test_deployPrivateVault() public {}
    function testRevert_deployPrivateVault_paused() public {}
    function testRevert_deployPrivateVault_notDeployer() public {}
    function testRevert_deployPrivateVault_initManagementFails()
        public
    {}

    // -- GETTER FUNCTIONS ----------------------------------------------------

    // - [ ] getTokenName
    //     - [ ] returns correct token name
    function test_getTokenName() public {}

    // - [ ] getTokenSymbol
    //     - [ ] returns correct token symbol
    function test_getTokenSymbol() public {}

    // - [ ] publicVaults
    //     - [ ] returns correct range of vault addresses
    //     - [ ] reverts if `start` is greater than `end`
    //     - [ ] reverts if `end` is greater than the number of public vaults
    function test_publicVaults() public {}
    function testRevert_publicVaults_startGtEnd() public {}
    function testRevert_publicVaults_endGtNbVaults() public {}

    // - [ ] numOfPublicVaults
    //     - [ ] returns correct number of public vaults
    function test_numOfPublicVaults() public {}

    // - [ ] privateVaults
    //     - [ ] returns correct range of vault addresses
    //     - [ ] reverts if `start` is greater than `end`
    //     - [ ] reverts if `end` is greater than the number of private vaults
    function test_privateVaults() public {}
    function testRevert_privateVaults_startGtEnd() public {}
    function testRevert_privateVaults_endGtNbVaults() public {}

    // - [ ] numOfPrivateVaults
    //     - [ ] returns correct number of private vaults
    function test_numOfPrivateVaults() public {}
}
