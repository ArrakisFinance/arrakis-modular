// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {console, Test} from "forge-std/Test.sol";

contract ArrakisMetaVaultFactoryTest is Test {
    function setUp() public {}

    // -- SETUP AND BASIC FUNCTIONS -------------------------------------------

    // - [ ] constructor
    //     - [ ] storage is properly set
    //     - [ ] reverts on zero address owner
    //     - [ ] reverts on zero address manager
    //     - [ ] reverts on zero address moduleRegistryPublic
    //     - [ ] reverts on zero address moduleRegistryPrivate
    function test_constructor() public {}
    function testRevert_constructor_addressZero_owner() public {}
    function testRevert_constructor_addressZero_manager() public {}
    function testRevert_constructor_addressZero_publicRegistry() public {}
    function testRevert_constructor_addressZero_privateRegistry() public {}

    // - [ ] pause
    //     - [ ] storage is properly updated
    //     - [ ] emits pause event
    //     - [ ] reverts when `msg.sender` is not the owner
    function test_pause() public {}
    function testRevert_pause_notOwner() public {}

    // - [ ] unpause
    //     - [ ] storage is properly updated
    //     - [ ] emits unpause event
    //     - [ ] reverts when `msg.sender` is not the owner
    function test_unpause() public {}
    function testRevert_unpause_notOwner() public {}

    // -- VAULT DEPLOYMENT FUNCTIONS -------------------------------------------

    // - [ ] deployPublicVault
    //     - [ ] `owner_` is set as a timelock proposer and executor
    //     - [ ] deploys a new timelock
    //     - [ ] deploys a new vault where timelock is the owner
    //     - [ ] deploys a new module from the public registry
    //     - [ ] adds vault to public vaults set
    //     - [ ] initializes the vault
    //     - [ ] initializes the vault's management on the manager
    //     - [ ] emits LogPublicVaultCreation event
    //     - [ ] reverts when paused
    //     - [ ] reverts when `msg.sender` is not a deployer
    //     - [ ] reverts when the management initialization fails
    function test_deployPublicVault() public {}
    function testRevert_deployPublicVault_paused() public {}
    function testRevert_deployPublicVault_notDeployer() public {}
    function testRevert_deployPublicVault_initManagementFails() public {}

    // - [ ] deployPrivateVault
    //     - [ ] deploys a new vault where the PALM NFT is the owner
    //     - [ ] mints a new PALM NFT for the owner
    //     - [ ] deploys a new module from the private registry
    //     - [ ] adds vault to private vaults set
    //     - [ ] initializes the vault
    //     - [ ] initializes the vault's management on the manager
    //     - [ ] emits LogPrivateVaultCreation event
    //     - [ ] reverts when paused
    //     - [ ] reverts when the management initialization fails
    function test_deployPrivateVault() public {}
    function testRevert_deployPrivateVault_paused() public {}
    function testRevert_deployPrivateVault_notDeployer() public {}
    function testRevert_deployPrivateVault_initManagementFails() public {}

    // -- GETTER FUNCTIONS -----------------------------------------------------

    // - [ ] getTokenName
    //     - [ ] returns correct token name
    function test_getTokenName() public {}

    // - [ ] getTokenSymbol
    //     - [ ] returns correct token symbol
    function test_getTokenSymbol() public {}

    // - [ ] publicVaults
    //     - [ ] returns correct range of vault addresses
    //     - [ ] reverts when `start` is greater than `end`
    //     - [ ] reverts when `end` is greater than the number of public vaults
    function test_publicVaults() public {}
    function testRevert_publicVaults_startGtEnd() public {}
    function testRevert_publicVaults_endGtNbVaults() public {}

    // - [ ] numOfPublicVaults
    //     - [ ] returns correct number of public vaults
    function test_numOfPublicVaults() public {}

    // - [ ] privateVaults
    //     - [ ] returns correct range of vault addresses
    //     - [ ] reverts when `start` is greater than `end`
    //     - [ ] reverts when `end` is greater than the number of private vaults
    function test_privateVaults() public {}
    function testRevert_privateVaults_startGtEnd() public {}
    function testRevert_privateVaults_endGtNbVaults() public {}

    // - [ ] numOfPrivateVaults
    //     - [ ] returns correct number of private vaults
    function test_numOfPrivateVaults() public {}
}