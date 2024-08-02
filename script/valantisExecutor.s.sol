// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {HOTExecutor} from
    "../src/modules/HOTExecutor.sol";

/// @dev after this script we should whitelist the valantis UpgradeableBeacon through the multisig
/// by calling whitelistBeacon of ModulePublicRegistry with the created UpgradeableBeacon.

address constant manager = 0xD0294EEE29287Bf69311552109F3FB84B3f2c1DC;
address constant w3f = 0xacf11AFFD3ED865FA2Df304eC5048C29597F38F9;
address constant owner = 0x969cA3961FCeaFd3Cb3C1CA9ecdd475babcD704D;

contract ValantisExecutor is Script {
    function setUp() public {}

    function run() public {
        uint256 privateKey = vm.envUint("PK_TEST");

        address account = vm.addr(privateKey);

        vm.startBroadcast(privateKey);

        address hotExecutor =
            address(new HOTExecutor(manager, w3f, owner));

        console.logString(
            "Hot Executor Address : "
        );
        console.logAddress(hotExecutor);

        vm.stopBroadcast();
    }
}
