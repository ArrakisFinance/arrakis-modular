// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";

import {ArrakisRoles} from "./constants/ArrakisRoles.sol";

import {ArrakisStandardManager} from
    "../../src/ArrakisStandardManager.sol";

contract InitManager is Script {
    address public constant manager =
        0xAD8B6C7DFac9c0Ce773649f84a5652550d7f2543;
    address public constant factory =
        0x1209BD3e8fAf1d142D925B4edaCc30c296d22bf1;

    function setUp() public {}

    function run() public {
        // owner multisig can do the deploymenet.
        // owner will also be the owner of guardian.
        address deployer = ArrakisRoles.getOwner();

        address owner = deployer;
        address defaultReceiver = deployer;

        console.logString("Deployer :");
        console.logAddress(deployer);

        bytes memory payload = abi.encodeWithSelector(
            ArrakisStandardManager.initialize.selector,
            owner,
            defaultReceiver,
            factory
        );

        console.logString("Payload :");
        console.logBytes(payload);
        console.logString("Send to :");
        console.logAddress(manager);

        vm.prank(deployer);
        ArrakisStandardManager(payable(manager)).initialize(
            owner, defaultReceiver, factory
        );
    }
}
