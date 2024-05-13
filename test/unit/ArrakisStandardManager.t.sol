// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console, Test} from "forge-std/Test.sol";

contract ArrakisStandardManagerTest is Test {
    function setUp() public {}

    // -- SETUP AND PERMISSIONED FUNCTIONS ------------------------------------

    // - [ ] constructor
    //     - [ ] storage is properly set
    //     - [ ] reverts if guardian is zero address
    //     - [ ] reverts if token is zero address
    //     - [ ] reverts if token decimals are zero
    function test_constructor() public {}
    function testRevert_constructor_zeroAddress_guardian() public {}
    function testRevert_constructor_zeroAddress_token() public {}
    function testRevert_constructor_zeroDecimals() public {}

    // - [ ] initialize
    //     - [ ] storage is properly set
    //     - [ ] emits `LogSetDefaultReceiver` event
    //     - [ ] reverts if owner is zero address
    //     - [ ] reverts if receiver is zero address
    //     - [ ] reverts if factory is zero address
    function test_initialize() public {}
    function testRevert_initialize_zeroAddress_owner() public {}
    function testRevert_initialize_zeroAddress_receiver() public {}
    function testRevert_initialize_zeroAddress_factory() public {}

    // - [ ] initManagement
    //     - [ ] storage is properly set
    //     - [ ] emits `LogSetManagementParams` event
    //     - [ ] reverts if `msg.sender` is not factory
    //     - [ ] reverts if vault is already managed
    //     - [ ] reverts if vault is address zero
    //     - [ ] reverts if vault is not deployed
    function test_initManagement() public {}
    function testRevert_initManagement_onlyFactory() public {}
    function testRevert_initManagement_alreadyManaged() public {}
    function testRevert_initManagement_zeroAddress_vault() public {}
    function testRevert_initManagement_notDeployedVault() public {}

    // - [ ] pause
    //     - [ ] contract is paused
    //     - [ ] emits `pause` event
    //     - [ ] reverts if `msg.sender` is not the guardian
    //     - [ ] reverts if the contract is already paused
    function test_pause() public {}
    function testRevert_pause_notGuardian() public {}
    function testRevert_pause_alreadyPaused() public {}

    // - [ ] unpause
    //     - [ ] contract is paused
    //     - [ ] emits `pause` event
    //     - [ ] reverts if `msg.sender` is not the guardian
    //     - [ ] reverts if the contract is not paused
    function test_unpause() public {}
    function testRevert_unpause_notGuardian() public {}
    function testRevert_unpause_notPaused() public {}

    // - [ ] setDefaultReceiver
    //     - [ ] storage is properly set
    //     - [ ] emits `LogSetDefaultReceiver` event
    //     - [ ] reverts if receiver is zero address
    //     - [ ] reverts if `msg.sender` is not the owner
    function test_setDefaultReceiver() public {}
    function testRevert_setDefaultReceiver_zeroAddress_owner()
        public
    {}
    function testRevert_setDefaultReceiver_onlyOwner() public {}

    // - [ ] setReceiverByToken
    //     - [ ] storage is properly set
    //     - [ ] emits `LogSetReceiverByToken` event
    //     - [ ] reverts if receiver is zero address
    //     - [ ] reverts if vault is not whitelisted
    //     - [ ] reverts if `msg.sender` is not the owner
    function test_setReceiverByToken_token0() public {}
    function test_setReceiverByToken_token1() public {}
    function testRevert_setReceiverByToken_zeroAddress_owner()
        public
    {}
    function testRevert_setReceiverByToken_onlyOwner() public {}
    function testRevert_setReceiverByToken_onlyWhitelistedVault()
        public
    {}

    // - [ ] decreaseManagerFeePIPs
    //     - [ ] storage is properly set
    //     - [ ] emits `LogChangeManagerFee` event
    //     - [ ] reverts if `msg.sender` is not the owner
    //     - [ ] reverts if vault is not whitelisted
    //     - [ ] reverts if new fee is not less than the current fee
    function test_decreaseManagerFeePIPs() public {}
    function testRevert_decreaseManagerFeePIPs_notOwner() public {}
    function testRevert_decreaseManagerFeePIPs_notWhitelistedVault()
        public
    {}
    function testRevert_decreaseManagerFeePIPs_gteCurrentFee()
        public
    {}

    // - [ ] submitIncreaseManagerFeePIPs
    //     - [ ] storage is properly set
    //     - [ ] emits `LogIncreaseManagerFeeSubmission` event
    //     - [ ] reverts if `msg.sender` is not the owner
    //     - [ ] reverts if vault is not whitelisted
    //     - [ ] reverts if new fee is not greater than the current fee
    //     - [ ] reverts if there is a pending increase
    function test_submitIncreaseManagerFeePIPs() public {}
    function testRevert_submitIncreaseManagerFeePIPs_notOwner()
        public
    {}
    function testRevert_submitIncreaseManagerFeePIPs_notWhitelistedVault(
    ) public {}
    function testRevert_submitIncreaseManagerFeePIPs_lteCurrentFee()
        public
    {}
    function testRevert_submitIncreaseManagerFeePIPs_pendingIncrease()
        public
    {}

    // - [ ] finalizeIncreaseManagerFeePIPs
    //     - [ ] storage is properly set
    //     - [ ] emits `LogChangeManagerFee` event
    //     - [ ] reverts if `msg.sender` is not the owner
    //     - [ ] reverts if there is no pending increase
    //     - [ ] reverts if not enough time has passed
    function test_finalizeIncreaseManagerFeePIPs() public {}
    function testRevert_finalizeIncreaseManagerFeePIPs_notOwner()
        public
    {}
    function testRevert_finalizeIncreaseManagerFeePIPs_noPendingIncrease(
    ) public {}
    function testRevert_finalizeIncreaseManagerFeePIPs_notEnoughTime()
        public
    {}

    // - [ ] setModule
    //     - [ ] storage is properly set
    //     - [ ] emits `LogSetModule` event
    //     - [ ] reverts if `msg.sender` is not the vault's executor
    //     - [ ] reverts if vault is not whitelisted
    //     - [ ] reverts if vault is paused
    function test_setModule() public {}
    function testRevert_setModule_notExecutor() public {}
    function testRevert_setModule_notWhitelistedVault() public {}
    function testRevert_setModule_pausedVault() public {}

    // - [ ] setFactory
    //     - [ ] storage is properly set
    //     - [ ] emits `LogSetFactory` event
    //     - [ ] reverts if `msg.sender` is not the owner
    //     - [ ] reverts if factory is zero address
    //     - [ ] reverts if factory is already set
    function test_setFactory() public {}
    function testRevert_setFactory_notOwner() public {}
    function testRevert_setFactory_zeroAddress_factory() public {}
    function testRevert_setFactory_alreadySet() public {}

    // - [ ] updateVaultInfo
    //     - [ ] storage is properly set
    //     - [ ] reverts if `msg.sender` is not the vault's owner
    //     - [ ] reverts if vault is not whitelisted
    //     - [ ] reverts if vault is paused
    //     - [ ] reverts if vault is not managed by the contract
    //     - [ ] reverts if oracle is zero address
    //     - [ ] reverts if maxSlippagePIPS is too high
    //     - [ ] reverts if cooldownPeriod is zero
    function test_updateVaultInfo() public {}
    function testRevert_updateVaultInfo_notVaultOwner() public {}
    function testRevert_updateVaultInfo_notWhitelistedVault()
        public
    {}
    function testRevert_updateVaultInfo_pausedVault() public {}
    function testRevert_updateVaultInfo_notManagedVault() public {}
    function testRevert_updateVaultInfo_params_noOracle() public {}
    function testRevert_updateVaultInfo_params_maxSlippagePIPS()
        public
    {}
    function testRevert_updateVaultInfo_params_zeroCooldownPeriod()
        public
    {}

    // -- OPERATIONAL FUNCTIONS -----------------------------------------------

    // - [ ] withdrawManagerBalance
    //     - [ ] calls `withdrawManagerBalance` on the module
    //     - [ ] sends token0 balance to the correct receiver
    //     - [ ] sends token1 balance to the correct receiver
    //     - [ ] emits `LogWithdrawManagerBalance` event
    //     - [ ] reverts if `msg.sender` is not the vault's owner
    //     - [ ] reverts if paused
    //     - [ ] reverts if reentered
    function test_withdrawManagerBalance_defaultReceiver() public {}
    function test_withdrawManagerBalance_receiverByToken0() public {}
    function test_withdrawManagerBalance_receiverByToken1() public {}
    function testRevert_withdrawManagerBalance_notOwner() public {}
    function testRevert_withdrawManagerBalance_paused() public {}
    function testRevert_withdrawManagerBalance_reentered() public {}

    // - [ ] rebalance
    //     - [ ] calls `validateRebalance` on the module
    //     - [ ] performs a low-level call to the module with the payloads
    //     - [ ] emits `LogRebalance` event
    //     - [ ] reverts if `msg.sender` is not the vault's executor
    //     - [ ] reverts if paused
    //     - [ ] reverts if reentered
    //     - [ ] reverts if vault is not whitelisted
    //     - [ ] reverts if not enough time has passed since last rebalance
    //     - [ ] reverts if low-level call fails
    //     - [ ] reverts if rebalace slippage is too high
    function test_rebalance() public {}
    function testRevert_rebalance_notExecutor() public {}
    function testRevert_rebalance_paused() public {}
    function testRevert_rebalance_reentered() public {}
    function testRevert_rebalance_notWhitelistedVault() public {}
    function testRevert_rebalance_notEnoughTimeElapsed() public {}
    function testRevert_rebalance_rebalanceCallFails() public {}
    function testRevert_rebalance_rebalanceSlippageTooHigh() public {}

    // -- GETTER FUNCTIONS ----------------------------------------------------

    // - [ ] initializedVaults
    //     - [ ] returns correct range of vault addresses
    //     - [ ] reverts if `start` is greater than `end`
    //     - [ ] reverts if `end` is greater than the number of initialized vaults
    function test_initializedVaults() public {}
    function testRevert_initializedVaults_startGtEnd() public {}
    function testRevert_initializedVaults_endGtVaults() public {}

    // - [ ] numInitializedVaults
    //     - [ ] returns the number of initialized vaults
    function test_numInitializedVaults() public {}

    // - [ ] guardian
    //     - [ ] returns guardian address
    function test_guardian() public {}

    // - [ ] isManaged
    //     - [ ] whether the vault is managed by the contract or not
    function test_isManaged() public {}
}
