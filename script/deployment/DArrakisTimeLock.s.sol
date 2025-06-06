// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

import {CreateXScript} from "./CreateXScript.sol";
import {ICreateX} from "./interfaces/ICreateX.sol";
import {ArrakisRoles} from "./constants/ArrakisRoles.sol";

import {TimelockController} from
    "@openzeppelin/contracts/governance/TimelockController.sol";

// ArrakisTimeLock : 0xAf6f9640092cB1236E5DB6E517576355b6C40b7f
contract DArrakisTimeLock is CreateXScript {
    uint88 public constant version = uint88(
        uint256(keccak256(abi.encode("Arrakis Time Lock version 1")))
    );

    uint256 constant minDelay = 2 days;

    function setUp() public {}

    function run() public {
        address proposer = ArrakisRoles.getOwner();
        address executor = proposer;

        // admin multisig will be the pauser.
        address timeLockAdmin = ArrakisRoles.getAdmin();

        vm.startBroadcast();

        console.logString("Deployer :");
        console.logAddress(msg.sender);

        address[] memory proposers = new address[](1);
        proposers[0] = proposer;

        address[] memory executors = new address[](1);
        executors[0] = executor;

        bytes memory initCode = abi.encodePacked(
            type(TimelockController).creationCode,
            abi.encode(minDelay, proposers, executors, timeLockAdmin)
        );

        bytes32 salt = bytes32(
            abi.encodePacked(msg.sender, hex"00", bytes11(version))
        );

        address implementation =
            computeCreate3Address(salt, msg.sender);

        console.logString("Arrakis Time Lock Address : ");
        console.logAddress(implementation);

        address actualAddr = CreateX.deployCreate3(salt, initCode);

        console.logString("Simulation Address :");
        console.logAddress(actualAddr);

        if (actualAddr != implementation) {
            revert("Create 3 addresses don't match.");
        }

        vm.stopBroadcast();
    }
}
