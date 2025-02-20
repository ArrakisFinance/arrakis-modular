// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

import {CreateXScript} from "./CreateXScript.sol";
import {ICreateX} from "./interfaces/ICreateX.sol";
import {ArrakisRoles} from "./constants/ArrakisRoles.sol";

import {ModulePublicRegistry} from
    "../../src/ModulePublicRegistry.sol";
import {ModulePrivateRegistry} from
    "../../src/ModulePrivateRegistry.sol";

// Public Registry : 0x791d75F87a701C3F7dFfcEC1B6094dB22c779603
// Private Registry: 0xe278C1944BA3321C1079aBF94961E9fF1127A265
contract DModuleRegistries is CreateXScript {
    uint88 public publicVersion = uint88(
        uint256(
            keccak256(abi.encode("Module Registry Public version 1"))
        )
    );

    uint88 public privateVersion = uint88(
        uint256(
            keccak256(abi.encode("Module Registry Private version 1"))
        )
    );

    address constant guardian =
        0x6F441151B478E0d60588f221f1A35BcC3f7aB981;
    address constant arrakisTimeLock =
        0xAf6f9640092cB1236E5DB6E517576355b6C40b7f;

    function setUp() public {}

    function run() public {
        address owner = ArrakisRoles.getOwner();

        vm.startBroadcast();

        console.logString("Deployer :");
        console.logAddress(msg.sender);

        // #region public registry.

        bytes memory initCode = abi.encodePacked(
            type(ModulePublicRegistry).creationCode,
            abi.encode(owner, guardian, arrakisTimeLock)
        );

        bytes32 salt = bytes32(
            abi.encodePacked(
                msg.sender, hex"00", bytes11(publicVersion)
            )
        );

        address publicRegistry =
            computeCreate3Address(salt, msg.sender);

        console.logString("Module Public Registry Address : ");
        console.logAddress(publicRegistry);

        address actualAddr = CreateX.deployCreate3(salt, initCode);

        console.logString(
            "Simulation Module Public Registry Address :"
        );
        console.logAddress(actualAddr);

        if (publicRegistry != actualAddr) {
            revert("Create 3 addresses don't match.");
        }

        // #endregion public registry.

        // #region private registry.

        initCode = abi.encodePacked(
            type(ModulePrivateRegistry).creationCode,
            abi.encode(owner, guardian, arrakisTimeLock)
        );

        salt = bytes32(
            abi.encodePacked(
                msg.sender, hex"00", bytes11(privateVersion)
            )
        );

        address privateRegistry =
            computeCreate3Address(salt, msg.sender);

        console.logString("Module Private Registry Address : ");
        console.logAddress(privateRegistry);

        actualAddr = CreateX.deployCreate3(salt, initCode);

        console.logString("Simulation Address :");
        console.logAddress(actualAddr);

        if (privateRegistry != actualAddr) {
            revert("Create 3 addresses don't match.");
        }

        // #endregion private registry.

        vm.stopBroadcast();
    }
}
