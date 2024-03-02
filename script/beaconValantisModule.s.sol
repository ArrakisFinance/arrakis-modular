// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {ValantisModulePublic} from
    "../src/modules/ValantisSOTModulePublic.sol";

import {UpgradeableBeacon} from
    "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

/// @dev after this script we should whitelist the valantis UpgradeableBeacon through the multisig
/// by calling whitelistBeacon of ModulePublicRegistry with the created UpgradeableBeacon.

address constant arrakisTimeLock =
    0x7726Ae33b359CAbaD7287CE5859018DC034c160D;
address constant guardian = 0x744c477Dc5658Ca8afe87A94771594Ac8c8302A5;

contract BeaconValantisModule is Script {
    function setUp() public {}

    function run() public {
        uint256 privateKey = vm.envUint("PK_TEST");

        address account = vm.addr(privateKey);

        vm.startBroadcast(privateKey);

        address implementation =
            address(new ValantisModulePublic(guardian));

        console.logString(
            "Valantis Module Public implementation Address : "
        );
        console.logAddress(implementation);

        address upgradeableBeacon = address(
            new UpgradeableBeacon(implementation, arrakisTimeLock)
        );

        console.logString("Upgradeable Beacon Valantis Address : ");
        console.logAddress(upgradeableBeacon);

        vm.stopBroadcast();
    }
}
