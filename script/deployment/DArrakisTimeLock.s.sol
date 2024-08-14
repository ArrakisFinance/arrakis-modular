// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

import {CreateXScript} from "./CreateXScript.sol";
import {ICreateX} from "./interfaces/ICreateX.sol";
import {ArrakisRoles} from "./constants/ArrakisRoles.sol";

import {TimelockController} from
    "@openzeppelin/contracts/governance/TimelockController.sol";

contract DArrakisTimeLock is CreateXScript {
    uint88 public constant version = uint88(
        uint256(keccak256(abi.encode("Arrakis Time Lock version 1")))
    );

    uint256 constant minDelay = 2 days;

    function setUp() public {}

    function run() public {
        uint256 privateKey = vm.envUint("PK");

        address deployer = vm.addr(privateKey);

        address proposer = ArrakisRoles.getOwner();
        address executor = proposer;

        // admin multisig will be the pauser.
        address timeLockAdmin = ArrakisRoles.getAdmin();

        console.logString("Deployer :");
        console.logAddress(deployer);

        vm.startBroadcast(privateKey);

        address[] memory proposers = new address[](1);
        proposers[0] = proposer;

        address[] memory executors = new address[](1);
        executors[0] = executor;

        bytes memory initCode = abi.encodePacked(
            type(TimelockController).creationCode,
            abi.encode(minDelay, proposers, executors, timeLockAdmin)
        );

        bytes32 salt = bytes32(
            abi.encodePacked(deployer, hex"00", bytes11(version))
        );

        address implementation = computeCreate3Address(salt, deployer);

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
