// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";

import {ArrakisRoles} from "./constants/ArrakisRoles.sol";

import {ArrakisStandardManager} from
    "../../src/ArrakisStandardManager.sol";

contract InitManager is Script {
    address public constant manager =
        0x2e6E879648293e939aA68bA4c6c129A1Be733bDA;
    address public constant factory =
        0x820FB8127a689327C863de8433278d6181123982;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        address owner = ArrakisRoles.getOwner();
        address defaultReceiver = owner;

        console.logString("Deployer :");
        console.logAddress(msg.sender);

        bytes memory payload = abi.encodeWithSelector(
            ArrakisStandardManager.initialize.selector,
            owner,
            defaultReceiver,
            factory
        );

        ArrakisStandardManager(payable(manager)).initialize(
            owner, defaultReceiver, factory
        );

        vm.stopBroadcast();
    }
}
