// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {TimeLock} from "../src/TimeLock.sol";

address constant timeLock = 0xCFaD8B6981Da1c734352Bd31618040C23FE99117;
bytes32 constant role = 0xb09aa5aeb3702cfd50b6b62bc4532604938f21248a27a1d5ca736082b6819cc1;
address constant acc = 0x81a1e7F34b9bABf172087cF5df8A4DF6500e9d4d;

contract RevokeRoleTimelock is Script {
    function setUp() public {}

    function run() public {
        uint256 privateKey = vm.envUint("PK_TEST");

        address account = vm.addr(privateKey);

        console.log(account);

        vm.startBroadcast(privateKey);

        TimeLock(payable(timeLock)).revokeRole(role, acc);

        console.logString("Revoke role to account successfully");

        vm.stopBroadcast();
    }
}
