// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";

import {ArrakisRoles} from "./constants/ArrakisRoles.sol";

import {ModuleRegistry} from "../../src/abstracts/ModuleRegistry.sol";

contract InitRegistries is Script {
    address public constant publicRegistry =
        0x791d75F87a701C3F7dFfcEC1B6094dB22c779603;
    address public constant privateRegistry =
        0xe278C1944BA3321C1079aBF94961E9fF1127A265;
    address public constant factory =
        0x820FB8127a689327C863de8433278d6181123982;

    function setUp() public {}

    function run() public {
        uint256 privateKey = vm.envUint("PK_TEST");

        vm.startBroadcast(privateKey);
        address deployer = vm.addr(privateKey);

        console.logString("Deployer :");
        console.logAddress(deployer);

        ModuleRegistry(publicRegistry).initialize(factory);
        ModuleRegistry(privateRegistry).initialize(factory);

        vm.stopBroadcast();
    }
}
