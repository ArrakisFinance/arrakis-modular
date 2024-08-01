// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

import {CreateXScript} from "./CreateXScript.sol";
import {ICreateX} from "./interfaces/ICreateX.sol";
import {ArrakisRoles} from "./constants/ArrakisRoles.sol";
import {CREATEX_ADDRESS} from "./constants/CCreateX.sol";

import {TimelockController} from
    "@openzeppelin/contracts/governance/TimelockController.sol";

contract DArrakisTimeLock is CreateXScript {
    uint88 public constant version = uint88(
        uint256(keccak256(abi.encode("Arrakis Time Lock version 1")))
    );

    uint256 constant minDelay = 2 days;

    function setUp() public {}

    function run() public {
        // owner multisig can do the deploymenet.
        // owner will also be the owner of guardian.
        address deployer = ArrakisRoles.getOwner();

        address proposer = deployer;
        address executor = deployer;

        // admin multisig will be the pauser.
        address timeLockAdmin = ArrakisRoles.getAdmin();

        console.logString("Deployer :");
        console.logAddress(deployer);

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

        bytes memory payload = abi.encodeWithSelector(
            ICreateX.deployCreate3.selector, salt, initCode
        );

        console.logString("Payload :");
        console.logBytes(payload);
        console.logString("Send to :");
        console.logAddress(CREATEX_ADDRESS);

        console.logString("Arrakis Time Lock Address : ");
        console.logAddress(computeCreate3Address(salt, deployer));

        vm.prank(deployer);

        address actualAddr = CreateX.deployCreate3(salt, initCode);

        console.logString("Simulation Address :");
        console.logAddress(actualAddr);
    }
}
