// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

import {CreateXScript} from "./CreateXScript.sol";
import {ICreateX} from "./interfaces/ICreateX.sol";
import {ArrakisRoles} from "./constants/ArrakisRoles.sol";
import {CREATEX_ADDRESS} from "./constants/CCreateX.sol";

import {ArrakisMetaVaultFactory} from
    "../../src/ArrakisMetaVaultFactory.sol";

contract DFactory is CreateXScript {
    uint88 public version =
        uint88(uint256(keccak256(abi.encode("Factory version 1"))));

    address public constant manager =
        0xAD8B6C7DFac9c0Ce773649f84a5652550d7f2543;
    address public constant publicRegistry =
        0x6C4F980fF2Ef4eB4580D909aA89d2d73c438029e;
    address public constant privateRegistry =
        0xc30F9Bb7d41c41fFD2639f6e203F4d52B19b6bCF;
    address public constant creationCodePublicVault =
        0xEC4BB009a737bAd1746138B6c0e8514cBb62817e;
    address public constant creationCodePrivateVault =
        0x5A361712C9092077cA99bb7cB1776b9d9F2DC14D;

    function setUp() public {}

    function run() public {
        // owner multisig can do the deploymenet.
        // owner will also be the owner of guardian.
        address deployer = ArrakisRoles.getOwner();

        address owner = deployer;

        console.logString("Deployer :");
        console.logAddress(deployer);

        bytes memory initCode = abi.encodePacked(
            type(ArrakisMetaVaultFactory).creationCode,
            abi.encode(
                owner,
                manager,
                publicRegistry,
                privateRegistry,
                creationCodePublicVault,
                creationCodePrivateVault
            )
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

        address factory = computeCreate3Address(salt, deployer);

        console.logString("Factory Address : ");
        console.logAddress(factory);

        vm.prank(deployer);

        address actualAddr = CreateX.deployCreate3(salt, initCode);

        console.logString("Simulation Address :");
        console.logAddress(actualAddr);

        if (factory != actualAddr) {
            revert("Create 3 addresses don't match.");
        }
    }
}
