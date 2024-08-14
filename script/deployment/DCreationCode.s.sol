// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

import {CreateXScript} from "./CreateXScript.sol";
import {ICreateX} from "./interfaces/ICreateX.sol";
import {ArrakisRoles} from "./constants/ArrakisRoles.sol";

import {CreationCodePublicVault} from
    "../../src/CreationCodePublicVault.sol";
import {CreationCodePrivateVault} from
    "../../src/CreationCodePrivateVault.sol";

// Code Creation Public : 0x374BCFff317203B5fab2c266b4a876d47E109331
// Code Creation Private : 0x69e58f06c4FB059E3F94Af3EB4DF64c57fdAb00f
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
        uint256 privateKey = vm.envUint("PK_TEST");

        address deployer = vm.addr(privateKey);

        console.logString("Deployer :");
        console.logAddress(deployer);

        vm.startBroadcast(privateKey);

        // #region public creation code.

        bytes memory initCode = abi.encodePacked(
            type(CreationCodePublicVault).creationCode
        );

        bytes32 salt = bytes32(
            abi.encodePacked(
                deployer, hex"00", bytes11(publicVersion)
            )
        );

        address publicCreationCode =
            computeCreate3Address(salt, deployer);

        console.logString("Creation Code Public Address : ");
        console.logAddress(publicCreationCode);

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

        address privateCreationCode =
            computeCreate3Address(salt, deployer);

        console.logString("Creation Code Private Address : ");
        console.logAddress(privateCreationCode);

        actualAddr = CreateX.deployCreate3(salt, initCode);

        console.logString("Simulation Address :");
        console.logAddress(actualAddr);

        if (privateCreationCode != actualAddr) {
            revert("Create 3 addresses don't match.");
        }

        // #endregion private creation code.

        vm.stopBroadcast();
    }
}
