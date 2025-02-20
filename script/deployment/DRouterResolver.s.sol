// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

import {CreateXScript} from "./CreateXScript.sol";
import {ICreateX} from "./interfaces/ICreateX.sol";
import {ArrakisRoles} from "./constants/ArrakisRoles.sol";

import {RouterSwapResolver} from "../../src/RouterSwapResolver.sol";

// Router Resolver : 0xC6c53369c36D6b4f4A6c195441Fe2d33149FB265
contract DRouterResolver is CreateXScript {
    uint88 public version = uint88(
        uint256(keccak256(abi.encode("Router Resolver version 1")))
    );

    address public constant router =
        0x72aa2C8e6B14F30131081401Fa999fC964A66041;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        console.logString("Deployer :");
        console.logAddress(msg.sender);

        bytes memory initCode = abi.encodePacked(
            type(RouterSwapResolver).creationCode, abi.encode(router)
        );

        bytes32 salt = bytes32(
            abi.encodePacked(msg.sender, hex"00", bytes11(version))
        );

        address routerResolver =
            computeCreate3Address(salt, msg.sender);

        console.logString("Router Resolver Address : ");
        console.logAddress(routerResolver);

        address actualAddr = CreateX.deployCreate3(salt, initCode);

        console.logString("Simulation Address :");
        console.logAddress(actualAddr);

        if (routerResolver != actualAddr) {
            revert("Create 3 addresses don't match.");
        }

        vm.stopBroadcast();
    }
}
