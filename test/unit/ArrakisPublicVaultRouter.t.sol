// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {console, Test} from "forge-std/Test.sol";

contract ArrakisPublicVaultRouterTest is Test {
    function setUp() public {}

    // -- SETUP AND PERMISSIONED FUNCTIONS ------------------------------------

    // - [ ] constructor
    //     - [ ] storage is properly set
    //     - [ ] reverts if native token is zero address
    //     - [ ] reverts if permit2 is zero address
    //     - [ ] reverts if swapper is zero address
    //     - [ ] reverts if owner is zero address
    function test_constructor() public {}
    function testRevert_constructor_zeroAddress_nativeToken() public {}
    function testRevert_constructor_zeroAddress_permit2() public {}
    function testRevert_constructor_zeroAddress_swapper() public {}
    function testRevert_constructor_zeroAddress_owner() public {}

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

    // -- OPERATIONAL FUNCTIONS -----------------------------------------------

    // - [ ] addLiquidity
    //     - [ ] if deposit non-native token, pulls token from `msg.sender`
    //     - [ ] calls `mint` on the vault
    //     - [ ] if deposit non-native token, module allowance is set before `mint` call
    //     - [ ] if deposit native token, `mint` call has value
    //     - [ ] if deposit native token and transfer is excessive, refunds `msg.sender`
    //     - [ ] reverts if contract is paused
    //     - [ ] reverts if vault is not PUBLIC_TYPE
    //     - [ ] reverts if max amounts are not set
    //     - [ ] reverts if minted shares are zero
    //     - [ ] reverts if minted amounts are below min amounts
    //     - [ ] reverts if not all tokens were transferred
    function test_addLiquidity_nativeToken_token0() public {}
    function test_addLiquidity_nativeToken_token1() public {}
    function test_addLiquidity_nativeToken_none() public {}
    function test_addLiquidity_nativeToken_refund() public {}
    function testRevert_addLiquidity_paused() public {}
    function testRevert_addLiquidity_notPublicType() public {}
    function testRevert_addLiquidity_noMaxAmounts() public {}
    function testRevert_addLiquidity_zeroMintedShares() public {}
    function testRevert_addLiquidity_belowMinAmounts() public {}
    function testRevert_addLiquidity_notAllTransferred() public {}

    // - [ ] swapAndAddLiquidity
    //     - [ ] if deposit non-native token, pulls token from `msg.sender`

}