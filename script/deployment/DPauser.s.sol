// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

import {CreateXScript} from "./CreateXScript.sol";
import {ICreateX} from "./interfaces/ICreateX.sol";
import {ArrakisRoles} from "./constants/ArrakisRoles.sol";

import {Pauser} from "../../src/Pauser.sol";

// Pauser : 0xfae375Bc5060A51343749CEcF5c8ABe65F11cCAC.
// Pauser v2 : 0x700a1cdA1495C1B34c4962e9742A8A8832aAc03A.
contract DPauser is CreateXScript {
    uint88 public version =
        uint88(uint256(keccak256(abi.encode("D Pauser version 2"))));

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        address owner = ArrakisRoles.getOwner();

        // admin multisig will be the pauser.
        address pauser = ArrakisRoles.getAdmin();

        console.logString("Deployer :");
        console.logAddress(msg.sender);

        bytes memory initCode = abi.encodePacked(
            type(Pauser).creationCode, abi.encode(pauser, owner)
        );

        bytes32 salt = bytes32(
            abi.encodePacked(msg.sender, hex"00", bytes11(version))
        );

        address implementation =
            computeCreate3Address(salt, msg.sender);

        console.logString("Pauser Address : ");
        console.logAddress(implementation);

        address actualAddr = CreateX.deployCreate3(salt, initCode);

        console.logString("Actual Pauser Address :");
        console.logAddress(actualAddr);

        if (actualAddr != implementation) {
            revert("Create 3 addresses don't match.");
        }

        vm.stopBroadcast();
    }
}
