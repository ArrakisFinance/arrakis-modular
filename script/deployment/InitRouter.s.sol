// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";

import {ArrakisRoles} from "./constants/ArrakisRoles.sol";

import {ArrakisPublicVaultRouterV2} from
    "../../src/ArrakisPublicVaultRouterV2.sol";
import {ArrakisPrivateVaultRouter} from
    "../../src/ArrakisPrivateVaultRouter.sol";

contract InitRouter is Script {
    address public constant router =
        0xEa9702Cf19BB348F17155E92357beF1Ed6F080B3;
    address public constant routerExecutor =
        0xC2d224E5781e9A173CaC4b387AeA9334a664beA7;

    function setUp() public {}

    function run() public {
        // owner multisig can do the deploymenet.
        // owner will also be the owner of guardian.
        address deployer = ArrakisRoles.getOwner();

        console.logString("Deployer :");
        console.logAddress(deployer);

        bytes memory payload = abi.encodeWithSelector(
            ArrakisPrivateVaultRouter.updateSwapExecutor.selector,
            routerExecutor
        );

        console.logString("Payload Public registry :");
        console.logBytes(payload);
        console.logString("Send to :");
        console.logAddress(router);
    }
}
