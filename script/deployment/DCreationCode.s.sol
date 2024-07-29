// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

import {CreateXScript} from "./CreateXScript.sol";
import {ICreateX} from "./interfaces/ICreateX.sol";
import {ArrakisRoles} from "./constants/ArrakisRoles.sol";
import {CREATEX_ADDRESS} from "./constants/CCreateX.sol";

import {CreationCodePublicVault} from
    "../../src/CreationCodePublicVault.sol";
import {CreationCodePrivateVault} from
    "../../src/CreationCodePrivateVault.sol";

contract DCreationCode is CreateXScript {
    uint88 public publicVersion = uint88(
        uint256(
            keccak256(abi.encode("Creation Code Public version 1"))
        )
    );

    uint88 public privateVersion = uint88(
        uint256(
            keccak256(abi.encode("Creation Code Private version 1"))
        )
    );

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

        // #region public creation code.

        bytes memory initCode = abi.encodePacked(
            type(CreationCodePublicVault).creationCode
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

        address publicCreationCode =
            computeCreate3Address(salt, deployer);

        console.logString("Creation Code Public Address : ");
        console.logAddress(publicCreationCode);

        vm.prank(deployer);
        address actualAddr = CreateX.deployCreate3(salt, initCode);

        console.logString("Simulation Address :");
        console.logAddress(actualAddr);

        if (publicCreationCode != actualAddr) {
            revert("Create 3 addresses don't match.");
        }

        // #endregion public creation code.

        // #region private creation code.

        initCode = abi.encodePacked(
            type(CreationCodePrivateVault).creationCode
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

        address privateCreationCode =
            computeCreate3Address(salt, deployer);

        console.logString("Creation Code Private Address : ");
        console.logAddress(privateCreationCode);

        vm.prank(deployer);
        actualAddr = CreateX.deployCreate3(salt, initCode);

        console.logString("Simulation Address :");
        console.logAddress(actualAddr);

        if (privateCreationCode != actualAddr) {
            revert("Create 3 addresses don't match.");
        }

        // #endregion private creation code.
    }
}
