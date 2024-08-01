// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";

import {ArrakisRoles} from "./constants/ArrakisRoles.sol";

import {ModuleRegistry} from "../../src/abstracts/ModuleRegistry.sol";

contract InitRegistries is Script {
    address public constant publicRegistry =
        0x6C4F980fF2Ef4eB4580D909aA89d2d73c438029e;
    address public constant privateRegistry =
        0xc30F9Bb7d41c41fFD2639f6e203F4d52B19b6bCF;
    address public constant factory =
        0x1209BD3e8fAf1d142D925B4edaCc30c296d22bf1;

    function setUp() public {}

    function run() public {
        // owner multisig can do the deploymenet.
        // owner will also be the owner of guardian.
        address deployer = ArrakisRoles.getOwner();

        console.logString("Deployer :");
        console.logAddress(deployer);

        bytes memory payload = abi.encodeWithSelector(
            ModuleRegistry.initialize.selector, factory
        );

        console.logString("Payload Public registry :");
        console.logBytes(payload);
        console.logString("Send to :");
        console.logAddress(publicRegistry);

        console.logString("Payload Private registry :");
        console.logBytes(payload);
        console.logString("Send to :");
        console.logAddress(privateRegistry);

        vm.startPrank(deployer);
        ModuleRegistry(publicRegistry).initialize(factory);
        ModuleRegistry(privateRegistry).initialize(factory);
        vm.stopPrank();
    }
}
