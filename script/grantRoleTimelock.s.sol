// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {TimeLock} from "../src/TimeLock.sol";

address constant timeLock = 0xCFaD8B6981Da1c734352Bd31618040C23FE99117;
bytes32 constant role =
    0xb09aa5aeb3702cfd50b6b62bc4532604938f21248a27a1d5ca736082b6819cc1;
address constant acc = 0x5108EF86cF493905BcD35A3736e4B46DeCD7de58;

contract GrantRoleTimelock is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        console.log(msg.sender);

        TimeLock(payable(timeLock)).grantRole(role, acc);

        console.logString("Grant role to account successfully");

        vm.stopBroadcast();
    }
}
