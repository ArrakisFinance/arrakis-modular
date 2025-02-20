// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {IHOT} from "@valantis-hot/contracts/interfaces/IHOT.sol";

contract HOTSetDeviationBound is Script {

    uint16 public constant maxOracleDeviationBipsLower = 350;
    uint16 public constant maxOracleDeviationBipsUpper = 350;

    function setup() public {}

    function run() public {
        bytes memory data = abi.encodeWithSelector(
            IHOT.setMaxOracleDeviationBips.selector,
            maxOracleDeviationBipsLower,
            maxOracleDeviationBipsUpper
        );

        console.logAddress(0x3269994964DFE4aa5f8dd0C99eD40e881562132A);
        console.logBytes(data);
    }
}