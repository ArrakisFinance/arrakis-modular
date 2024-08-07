// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

import {CreateXScript} from "./CreateXScript.sol";
import {ICreateX} from "./interfaces/ICreateX.sol";
import {ArrakisRoles} from "./constants/ArrakisRoles.sol";

import {Guardian} from "../../src/Guardian.sol";

contract DGuardian is CreateXScript {
    uint88 public version =
        uint88(uint256(keccak256(abi.encode("D Guardian version 1"))));

    function setUp() public {}

    function run() public {
        uint256 privateKey = vm.envUint("PK");

        address deployer = vm.addr(privateKey);

        vm.startBroadcast(privateKey);

        address owner = ArrakisRoles.getOwner();

        // admin multisig will be the pauser.
        address pauser = ArrakisRoles.getAdmin();

        console.logString("Deployer :");
        console.logAddress(deployer);

        bytes memory initCode = abi.encodePacked(
            type(Guardian).creationCode, abi.encode(owner, pauser)
        );

        bytes32 salt = bytes32(
            abi.encodePacked(deployer, hex"00", bytes11(version))
        );

        address implementation = computeCreate3Address(salt, deployer);

        console.logString("Guardian Address : ");
        console.logAddress(implementation);

        address actualAddr = CreateX.deployCreate3(salt, initCode);

        console.logString("Actual Guardian Address :");
        console.logAddress(actualAddr);

        if (actualAddr != implementation) {
            revert("Create 3 addresses don't match.");
        }

        vm.stopBroadcast();
    }
}
