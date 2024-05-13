// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

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
    function testRevert_constructor_zeroAddress_nativeToken()
        public
    {}
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
    //     - [ ] if deposit native token and transfer is excessive, refunds `msg.sender`
    //     - [ ] reverts if contract is paused
    //     - [ ] reverts if contract is reentered
    //     - [ ] reverts if vault is not PUBLIC_TYPE
    //     - [ ] reverts if max amounts are not set
    //     - [ ] reverts if minted shares are zero
    //     - [ ] reverts if minted amounts are below min amounts
    // - [ ] _addLiquidity (internal function)
    //     - [ ] calls `mint` on the vault
    //     - [ ] if deposit non-native token, module allowance is set before `mint` call
    //     - [ ] if deposit native token, `mint` call has value
    //     - [ ] reverts if not all tokens were transferred after `mint` call
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
    //     - [ ] reverts if contract is paused
    //     - [ ] reverts if contract is reentered
    //     - [ ] reverts if vault is not PUBLIC_TYPE
    //     - [ ] reverts if max amounts are not set
    //     - [ ] reverts if not enough native token is sent
    // - [ ] _swapAndAddLiquidity (internal function)
    //     - [ ] calls `swap` on the swapper with the swap payload
    //     - [ ] if deposit non-native token, swapper allowance is set before `swap` call
    //     - [ ] if deposit native token and transfer is excessive, refunds `msg.sender`
    //     - [ ] reverts if minted shares are zero
    // - [ ] _addLiquidity (internal function)
    function test_swapAndAddLiquidity_nativeToken_token0_zeroForOne()
        public
    {}
    function test_swapAndAddLiquidity_nativeToken_token0_oneForZero()
        public
    {}
    function test_swapAndAddLiquidity_nativeToken_token1_zeroForOne()
        public
    {}
    function test_swapAndAddLiquidity_nativeToken_token1_oneForZero()
        public
    {}
    function test_swapAndAddLiquidity_nativeToken_none_zeroForOne()
        public
    {}
    function test_swapAndAddLiquidity_nativeToken_none_oneForZero()
        public
    {}
    function test_swapAndAddLiquidity_nativeToken_refund() public {}
    function testRevert_swapAndAddLiquidity_paused() public {}
    function testRevert_swapAndAddLiquidity_notPublicType() public {}
    function testRevert_swapAndAddLiquidity_reentered() public {}
    function testRevert_swapAndAddLiquidity_noMaxAmounts() public {}
    function testRevert_swapAndAddLiquidity_notEnoughNativeToken()
        public
    {}
    function testRevert_swapAndAddLiquidity_zeroMintedShares()
        public
    {}

    // - [ ] removeLiquidity
    //     - [ ] reverts if contract is paused
    //     - [ ] reverts if contract is reentered
    //     - [ ] reverts if vault is not PUBLIC_TYPE
    //     - [ ] reverts if burn amount is zero
    // - [ ] _removeLiquidity (internal function)
    //     - [ ] calls `burn` on the vault
    //     - [ ] reverts if withdraw amount is below min amounts
    function test_removeLiquidity() public {}
    function testRevert_removeLiquidity_paused() public {}
    function testRevert_removeLiquidity_notPublicType() public {}
    function testRevert_removeLiquidity_reentered() public {}
    function testRevert_removeLiquidity_zeroBurnAmount() public {}
    function testRevert_removeLiquidity_belowMinAmounts() public {}

    // - [ ] addLiquidityPermit2
    //     - [ ] reverts if contract is paused
    //     - [ ] reverts if contract is reentered
    //     - [ ] reverts if vault is not PUBLIC_TYPE
    //     - [ ] reverts if max amounts are not set
    //     - [ ] reverts if minted shares are zero
    //     - [ ] reverts if minted amounts are below min amounts
    //     - [ ] reverts if one of the tokens is the native token
    // - [ ] _permit2Add (internal function)
    //     - [ ] calls `permitTransferFrom` on the permit2 contract
    //     - [ ] reverts if payload doesn't have permit2 signature for each token
    // - [ ] _addLiquidity (internal function)
    function test_addLiquidityPermit2() public {}
    function testRevert_addLiquidityPermit2_paused() public {}
    function testRevert_addLiquidityPermit2_notPublicType() public {}
    function testRevert_addLiquidityPermit2_reentered() public {}
    function testRevert_addLiquidityPermit2_noMaxAmounts() public {}
    function testRevert_addLiquidityPermit2_zeroMintedShares()
        public
    {}
    function testRevert_addLiquidityPermit2_belowMinAmounts()
        public
    {}
    function testRevert_addLiquidityPermit2_nativeToken() public {}
    function testRevert_addLiquidityPermit2_missingSignature()
        public
    {}

    // - [ ] swapAndAddLiquidityPermit2
    //     - [ ] reverts if contract is paused
    //     - [ ] reverts if contract is reentered
    //     - [ ] reverts if vault is not PUBLIC_TYPE
    //     - [ ] reverts if max amounts are not set
    //     - [ ] reverts if one of the tokens is the native token
    // - [ ] _permit2SwapAndAdd (internal function)
    //     - [ ] calls `permitTransferFrom` on the permit2 contract
    //     - [ ] reverts if payload doesn't have permit2 signature for each token
    // - [ ] _swapAndAddLiquidity (internal function)
    function test_swapAndAddLiquidityPermit2() public {}
    function testRevert_swapAndAddLiquidityPermit2_paused() public {}
    function testRevert_swapAndAddLiquidityPermit2_notPublicType()
        public
    {}
    function testRevert_swapAndAddLiquidityPermit2_reentered()
        public
    {}
    function testRevert_swapAndAddLiquidityPermit2_noMaxAmounts()
        public
    {}
    function testRevert_swapAndAddLiquidityPermit2_nativeToken()
        public
    {}
    function testRevert_swapAndAddLiquidityPermit2_missingSignature()
        public
    {}

    // - [ ] removeLiquidityPermit2
    //     - [ ] reverts if contract is paused
    //     - [ ] reverts if contract is reentered
    //     - [ ] reverts if vault is not PUBLIC_TYPE
    //     - [ ] reverts if burn amount is zero
    // - [ ] _removeLiquidity (internal function)
    function test_removeLiquidityPermit2() public {}
    function testRevert_removeLiquidityPermit2_paused() public {}
    function testRevert_removeLiquidityPermit2_notPublicType()
        public
    {}
    function testRevert_removeLiquidityPermit2_reentered() public {}
    function testRevert_removeLiquidityPermit2_zeroBurnAmount()
        public
    {}
}
