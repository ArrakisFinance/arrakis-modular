// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

import {CreateXScript} from "./CreateXScript.sol";
import {ICreateX} from "./interfaces/ICreateX.sol";
import {ArrakisRoles} from "./constants/ArrakisRoles.sol";
import {CREATEX_ADDRESS} from "./constants/CCreateX.sol";

import {RouterSwapExecutor} from "../../src/RouterSwapExecutor.sol";
import {NATIVE_COIN} from "../../src/constants/CArrakis.sol";

contract DRouterExecutor is CreateXScript {
    uint88 public version = uint88(
        uint256(keccak256(abi.encode("Router Executor version 1")))
    );

    address public constant router =
        0xFf24347dA277476d11c462Ea7314BA04fb8Fb793;

    function setUp() public {}

    function run() public {
        // owner multisig can do the deploymenet.
        // owner will also be the owner of guardian.
        address deployer = ArrakisRoles.getOwner();

        address owner = deployer;

        console.logString("Deployer :");
        console.logAddress(deployer);

        bytes memory initCode = abi.encodePacked(
            type(RouterSwapExecutor).creationCode,
            abi.encode(router, NATIVE_COIN)
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

        address routerExecutor = computeCreate3Address(salt, deployer);

        console.logString("Router Executor Address : ");
        console.logAddress(routerExecutor);

        vm.prank(deployer);

        address actualAddr = CreateX.deployCreate3(salt, initCode);

        console.logString("Simulation Address :");
        console.logAddress(actualAddr);

        if (routerExecutor != actualAddr) {
            revert("Create 3 addresses don't match.");
        }
    }
}
