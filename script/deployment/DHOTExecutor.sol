// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

import {CreateXScript} from "./CreateXScript.sol";
import {ICreateX} from "./interfaces/ICreateX.sol";
import {ArrakisRoles} from "./constants/ArrakisRoles.sol";

import {HOTExecutor} from "../../src/modules/HOTExecutor.sol";

address constant manager = 0x2e6E879648293e939aA68bA4c6c129A1Be733bDA;
address constant w3f = 0xacf11AFFD3ED865FA2Df304eC5048C29597F38F9;

// HOTExecutor : 0x030DE9fd3ca63AB012f4E22dB595b66C812c8525.
// New HOTExecutor : 0x0C3Aed3cAB3827df14B13FfF38E9f38a7c6B9464.
contract DHOTExecutor is CreateXScript {
    uint88 public version = uint88(
        uint256(keccak256(abi.encode("D HOT Executor version 2")))
    );

    function setUp() public {}

    function run() public {
        uint256 privateKey = vm.envUint("PK");

        address deployer = vm.addr(privateKey);

        vm.startBroadcast(privateKey);

        address owner = ArrakisRoles.getOwner();

        console.logString("Deployer :");
        console.logAddress(deployer);

        bytes memory initCode = abi.encodePacked(
            type(HOTExecutor).creationCode,
            abi.encode(manager, w3f, owner)
        );

        bytes32 salt = bytes32(
            abi.encodePacked(deployer, hex"00", bytes11(version))
        );

        address implementation = computeCreate3Address(salt, deployer);

        console.logString("HOT Executor Address : ");
        console.logAddress(implementation);

        address actualAddr = CreateX.deployCreate3(salt, initCode);

        console.logString("Actual HOT Executor Address :");
        console.logAddress(actualAddr);

        if (actualAddr != implementation) {
            revert("Create 3 addresses don't match.");
        }

        vm.stopBroadcast();
    }
}
