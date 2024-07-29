// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

import {CreateXScript} from "./CreateXScript.sol";
import {ICreateX} from "./interfaces/ICreateX.sol";
import {ArrakisRoles} from "./constants/ArrakisRoles.sol";
import {CREATEX_ADDRESS} from "./constants/CCreateX.sol";

import {ModulePublicRegistry} from
    "../../src/ModulePublicRegistry.sol";
import {ModulePrivateRegistry} from
    "../../src/ModulePrivateRegistry.sol";

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

    address public constant guardian =
        0x3Cc5ceaFc3F68D79937fC87582a6343d2Fa2C4a5;
    address public constant arrakisTimeLock =
        0x9FE545267089DCa885aA9DB2287eEe0B829CC1E7;

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

        // #region public registry.

        bytes memory initCode = abi.encodePacked(
            type(ModulePublicRegistry).creationCode,
            abi.encode(owner, guardian, arrakisTimeLock)
        );

        bytes32 salt = bytes32(
            abi.encodePacked(
                deployer, hex"00", bytes11(publicVersion)
            )
        );

        bytes memory payload = abi.encodeWithSelector(
            ICreateX.deployCreate3.selector, salt, initCode
        );

        console.logString("Payload :");
        console.logBytes(payload);
        console.logString("Send to :");
        console.logAddress(CREATEX_ADDRESS);

        address publicRegistry = computeCreate3Address(salt, deployer);

        console.logString("Module Public Registry Address : ");
        console.logAddress(publicRegistry);

        vm.prank(deployer);
        address actualAddr = CreateX.deployCreate3(salt, initCode);

        console.logString("Simulation Address :");
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
                deployer, hex"00", bytes11(privateVersion)
            )
        );

        payload = abi.encodeWithSelector(
            ICreateX.deployCreate3.selector, salt, initCode
        );

        console.logString("Payload :");
        console.logBytes(payload);
        console.logString("Send to :");
        console.logAddress(CREATEX_ADDRESS);

        address privateRegistry =
            computeCreate3Address(salt, deployer);

        console.logString("Module Private Registry Address : ");
        console.logAddress(privateRegistry);

        vm.prank(deployer);
        actualAddr = CreateX.deployCreate3(salt, initCode);

        console.logString("Simulation Address :");
        console.logAddress(actualAddr);

        if (privateRegistry != actualAddr) {
            revert("Create 3 addresses don't match.");
        }

        // #endregion private registry.
    }
}
