// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

import {CreateXScript} from "./CreateXScript.sol";
import {ICreateX} from "./interfaces/ICreateX.sol";

import {ArrakisPrivateHookFactory} from "../../src/hooks/ArrakisPrivateHookFactory.sol";

// ArrakisPrivateHookFactory : 0xCd2430B875E600ae94ABBfA27c776e03F29C9232
contract DArrakisPrivateHookFactory is CreateXScript {
    uint88 public version = uint88(
        uint256(
            keccak256(abi.encode("Arrakis Private Hook Factory version 1"))
        )
    );

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        console.logString("Deployer :");
        console.logAddress(msg.sender);

        bytes memory initCode = abi.encodePacked(
            type(ArrakisPrivateHookFactory).creationCode
        );

        bytes32 salt = bytes32(
            abi.encodePacked(msg.sender, hex"00", bytes11(version))
        );

        address implementation = computeCreate3Address(salt, msg.sender);

        console.logString("Arrakis Private Hook Factory Address : ");
        console.logAddress(implementation);

        address actualAddr = CreateX.deployCreate3(salt, initCode);

        console.logString("Actual Arrakis Private Hook Factory Address :");
        console.logAddress(actualAddr);

        if (actualAddr != implementation) {
            revert("Create 3 addresses don't match.");
        }

        vm.stopBroadcast();
    }
}
