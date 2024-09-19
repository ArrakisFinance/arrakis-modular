// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {IHOT} from "@valantis-hot/contracts/interfaces/IHOT.sol";

contract SetTokenMaxVolume is Script {
    function setUp() public {}

    function run() public {
        bytes memory data = abi.encodeWithSelector(
            IHOT.setMaxTokenVolumes.selector,
            1000 ether,
            2_000_000_000_000
        );

        console.logBytes(data);
    }
}
