// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console, Test} from "forge-std/Test.sol";

contract RouterSwapExecutorTest is Test {
    function setUp() public {}

    // -- SETUP AND PERMISSIONED FUNCTIONS ------------------------------------

    // - [ ] constructor
    //     - [ ] storage is properly set
    //     - [ ] reverts if router is zero address
    //     - [ ] reverts if native token is zero address
    function test_constructor() public {}
    function testRevert_constructor_zeroAddress_router() public {}
    function testRevert_constructor_zeroAddress_nativeToken()
        public
    {}

    // - [ ] swap
    //     - [ ] if swaped token is native token, uses account balance
    //     - [ ] if swaped token is not native token, pulls token from router
    //     - [ ] performs a low-level call to router with the swap payload
    //     - [ ] send the swap output back to the router
    //     - [ ] returns the difference in token0 and token1 balances
    //     - [ ] reverts if not called by router
    //     - [ ] reverts if router call fails
    //     - [ ] reverts if swap output is below minimum
    function test_swap_nativeToken_token0() public {}
    function test_swap_nativeToken_token1() public {}
    function test_swap_nativeToken_none() public {}
    function testRevert_swap_notRouter() public {}
    function testRevert_swap_callFails() public {}
    function testRevert_swap_outputBelowMinimum() public {}
}
