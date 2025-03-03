// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

import {CreateXScript} from "./CreateXScript.sol";
import {ICreateX} from "./interfaces/ICreateX.sol";

import {NFTSVG} from "../../src/utils/NFTSVG.sol";

// NFTSVGUtils Base : 0xB0eA63D67c815Dc602ba53ee1dCFEbBA9Ae5aD7b.
// NFTSVG Base : 0x01C777eDd94411d9e7319cE226299EB8F96A3Ca9.
contract DNFTSVG is CreateXScript {
    uint88 public version =
        uint88(uint256(keccak256(abi.encode("NFTSVG version 1"))));

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        console.logString("Deployer :");
        console.logAddress(msg.sender);

        bytes memory initCode =
            abi.encodePacked(type(NFTSVG).creationCode);

        bytes32 salt = bytes32(
            abi.encodePacked(msg.sender, hex"00", bytes11(version))
        );

        address nftSVG = computeCreate3Address(salt, msg.sender);

        console.logString("NFTSVG Address : ");
        console.logAddress(nftSVG);

        address actualAddr = CreateX.deployCreate3(salt, initCode);

        console.logString("Simulation Address :");
        console.logAddress(actualAddr);

        if (nftSVG != actualAddr) {
            revert("Create 3 addresses don't match.");
        }

        vm.stopBroadcast();
    }
}
