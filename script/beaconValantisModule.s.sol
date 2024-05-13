// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {ValantisModulePublic} from
    "../src/modules/ValantisHOTModulePublic.sol";

import {UpgradeableBeacon} from
    "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

/// @dev after this script we should whitelist the valantis UpgradeableBeacon through the multisig
/// by calling whitelistBeacon of ModulePublicRegistry with the created UpgradeableBeacon.

address constant arrakisTimeLock =
    0x97e2f0355169485A02B4e4b6c1dA2eb7BB328D7b;
address constant guardian = 0x7BF13492D11eE0f129201247Cc3aCd59206D7503;

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

        address upgradeableBeacon =
            address(new UpgradeableBeacon(implementation));

        UpgradeableBeacon(upgradeableBeacon).transferOwnership(
            arrakisTimeLock
        );

        console.logString("Upgradeable Beacon Valantis Address : ");
        console.logAddress(upgradeableBeacon);

        vm.stopBroadcast();
    }
}
