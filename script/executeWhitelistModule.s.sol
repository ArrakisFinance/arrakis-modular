// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {IArrakisMetaVault} from
    "../src/interfaces/IArrakisMetaVault.sol";
import {IBunkerModule} from "../src/interfaces/IBunkerModule.sol";
import {TimeLock} from "../src/TimeLock.sol";

/// @dev ask to valantis team to grant module as poolManager (sovereignPool) and
/// liquidityProvider (hot alm) before running this script.

address constant vault = 0xf790870ccF6aE66DdC69f68e6d05d446f1a6ad83;
address constant timeLock = 0xCFaD8B6981Da1c734352Bd31618040C23FE99117;
address constant beacon = 0xe25F763fa58de798AF2e454e916F527cdD17E885;

// mainnet bunker module 0xE7192EFbb58e19C2A8954CC27EebB2cc8e434538 for vault 0xf790870ccF6aE66DdC69f68e6d05d446f1a6ad83.
contract ExecuteWhitelistModule is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        console.log(msg.sender);

        address[] memory beacons = new address[](1);
        beacons[0] = beacon;

        bytes[] memory payloads = new bytes[](1);
        payloads[0] = abi.encodeWithSelector(
            IBunkerModule.initialize.selector, vault
        );

        bytes memory data = abi.encodeWithSelector(
            IArrakisMetaVault.whitelistModules.selector,
            beacons,
            payloads
        );

        TimeLock(payable(timeLock)).execute(
            vault, 0, data, bytes32(0), bytes32(0)
        );

        console.logString("Execute Module whitelisting!");

        vm.stopPrank();

        // vm.stopBroadcast();
    }
}
