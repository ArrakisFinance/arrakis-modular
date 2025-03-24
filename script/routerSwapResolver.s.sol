// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {RouterSwapResolver} from "../src/RouterSwapResolver.sol";

/// @dev ask to valantis team to grant module as poolManager (sovereignPool) and
/// liquidityProvider (hot alm) before running this script.

address constant router = 0xd3Db920D1403a5438A50d73f375b0DFf5a6Df9fC;

contract RouterSwapResolverDeployment is Script {
    function setUp() public {}

    function run() public {

        vm.startBroadcast();

        console.log(msg.sender);

        address routerSwapResover =
            address(new RouterSwapResolver(router));

        console.logString("Router Swap Resolver Address : ");
        console.logAddress(routerSwapResover);

        vm.stopPrank();

        // vm.stopBroadcast();
    }
}
