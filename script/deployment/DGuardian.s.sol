// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

import {CreateXScript} from "./CreateXScript.sol";
import {ICreateX} from "./interfaces/ICreateX.sol";
import {ArrakisRoles} from "./constants/ArrakisRoles.sol";
import {CREATEX_ADDRESS} from "./constants/CCreateX.sol";

import {Guardian} from "../../src/Guardian.sol";

contract DGuardian is CreateXScript {
    uint88 public version =
        uint88(uint256(keccak256(abi.encode("D Guardian version 1"))));

    function setUp() public {}

    function run() public {
        // owner multisig can do the deploymenet.
        // owner will also be the owner of guardian.
        address deployer = ArrakisRoles.getOwner();

        address owner = deployer;

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

        bytes memory payload = abi.encodeWithSelector(
            ICreateX.deployCreate3.selector, salt, initCode
        );

        console.logString("Payload :");
        console.logBytes(payload);
        console.logString("Send to :");
        console.logAddress(CREATEX_ADDRESS);

        console.logString("Guardian Address : ");
        console.logAddress(computeCreate3Address(salt, deployer));

        vm.prank(deployer);

        address actualAddr = CreateX.deployCreate3(salt, initCode);

        console.logString("Simulation Address :");
        console.logAddress(actualAddr);
    }
}
