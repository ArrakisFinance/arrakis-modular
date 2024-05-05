// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {Dex} from "../test/tests/Dex.sol";

/// @dev before this script we should whitelist the deployer as public vault deployer using the multisig
/// on the factory side.

address constant token0 = address(0);
address constant token1 = address(0);

contract DeployDex is Script {
    function setUp() public {}

    function run() public {
        uint256 privateKey = vm.envUint("PK_TEST");

        address account = vm.addr(privateKey);

        console.logString("Deployer : ");
        console.logAddress(account);

        vm.startBroadcast(privateKey);

        address dex = address(new Dex(token0, token1));

        console.logString("Dex deployment : ");
        console.logAddress(dex);

        vm.stopBroadcast();
    }
}
