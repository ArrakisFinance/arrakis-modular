// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console, Test} from "forge-std/Test.sol";

contract ArrakisMetaVaultTest is Test {
    function setUp() public {}

    // -- SETUP AND PERMISSIONED FUNCTIONS ------------------------------------

    // - [ ] constructor
    //     - [ ] storage is properly set
    //     - [ ] emits `LogSetManager` event
    //     - [ ] reverts if token0 is zero address
    //     - [ ] reverts if token1 is zero address
    //     - [ ] reverts if manager is zero address
    //     - [ ] reverts if moduleRegistry is zero address
    //     - [ ] reverts if token0 is greater than token1
    //     - [ ] reverts if token0 equals token1
    function test_constructor() public {}
    function testRevert_constructor_zeroAddress_token0() public {}
    function testRevert_constructor_zeroAddress_token1() public {}
    function testRevert_constructor_zeroAddress_manager() public {}
    function testRevert_constructor_zeroAddress_moduleRegistry()
        public
    {}
    function testRevert_constructor_wrongTokenOrder() public {}
    function testRevert_constructor_sameTokens() public {}

    // - [ ] initialize
    //     - [ ] module is whitelisted and set
    //     - [ ] emits `LogSetFirstModule` event
    //     - [ ] emits `LogWhitelistedModule` event
    //     - [ ] reverts if module is zero address
    function test_initialize() public {}
    function testRevert_zeroAddress_module() public {}

    // - [ ] setModule
    //     - [ ] module is properly set
    //     - [ ] calls `withdraw()` on the old module
    //     - [ ] calls `withdrawManagerBalance()` on the old module
    //     - [ ] new module is called with the input payloads
    //     - [ ] emits `LogWithdraw` event
    //     - [ ] emits `LogWithdrawManagerBalance` event
    //     - [ ] emits `LogSetModule` event
    //     - [ ] reverts if `msg.sender` is not the manager
    //     - [ ] reverts if module is already set
    //     - [ ] reverts if module is not whitelisted
    //     - [ ] reverts if old module is not emptied
    //     - [ ] reverts if module call fails
    //     - [ ] reverts if the function is reentered
    function test_setModule() public {}
    function testRevert_setModule_onlyManager() public {}
    function testRevert_setModule_nonReentrant() public {}
    function testRevert_setModule_moduleAlreadySet() public {}
    function testRevert_setModule_moduleNotWhitelisted() public {}
    function testRevert_setModule_moduleNotEmpty() public {}
    function testRevert_setModule_moduleCallFailed() public {}

    // - [ ] whitelistModules
    //     - [ ] modules are properly deployed and whitelisted
    //     - [ ] emits `LogWhiteListedModules` event
    //     - [ ] reverts if onlyOwnerCheck check fails
    //     - [ ] reverts if beacons and data have different lengths
    function test_whitelistModules() public {}
    function testRevert_whitelistModules_onlyOwnerCheck() public {}
    function testRevert_whitelistModules_differentLengths() public {}

    // - [ ] blacklistModules
    //     - [ ] modules are properly removed from the whitelist
    //     - [ ] emits `LogBlackListedModules` event
    //     - [ ] reverts if onlyOwnerCheck check fails
    //     - [ ] reverts if a module is not whitelisted
    //     - [ ] reverts if a module is active
    function test_blacklistModules() public {}
    function testRevert_blacklistModules_onlyOwnerCheck() public {}
    function testRevert_blacklistModules_notWhitelisted() public {}
    function testRevert_blacklistModules_stillActive() public {}

    // -- GETTER FUNCTIONS ----------------------------------------------------

    // - [ ] getInits
    //     - [ ] calls `getInits()` on the module
    function test_getInits() public {}

    // - [ ] totalUnderlying
    //     - [ ] calls `totalUnderlying()` on the module
    function test_totalUnderlying() public {}

    // - [ ] totalUnderlyingAtPrice
    //     - [ ] calls `totalUnderlyingAtPrice()` on the module
    function test_totalUnderlyingAtPrice() public {}
}
