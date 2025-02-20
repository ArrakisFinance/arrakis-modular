// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

import {CreateXScript} from "./CreateXScript.sol";
import {ICreateX} from "./interfaces/ICreateX.sol";
import {ArrakisRoles} from "./constants/ArrakisRoles.sol";

import {PrivateRouterSwapExecutor} from
    "../../src/PrivateRouterSwapExecutor.sol";
import {NATIVE_COIN} from "../../src/constants/CArrakis.sol";

// Private RouterExecutor Test : 0x19488620Cdf3Ff1B0784AC4529Fb5c5AbAceb1B6.
// Private RouterExecutor : 0xC2d224E5781e9A173CaC4b387AeA9334a664beA7.
contract DPrivateRouterExecutor is CreateXScript {
    uint88 public version = uint88(
        uint256(
            keccak256(abi.encode("Private Router Executor version 1"))
        )
    );

    address public constant router =
        0xEa9702Cf19BB348F17155E92357beF1Ed6F080B3;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        console.logString("Deployer :");
        console.logAddress(msg.sender);

        bytes memory initCode = abi.encodePacked(
            type(PrivateRouterSwapExecutor).creationCode,
            abi.encode(router, NATIVE_COIN)
        );

        bytes32 salt = bytes32(
            abi.encodePacked(msg.sender, hex"00", bytes11(version))
        );

        address privateRouterExecutor =
            computeCreate3Address(salt, msg.sender);

        console.logString("Private Router Executor Address : ");
        console.logAddress(privateRouterExecutor);

        address actualAddr = CreateX.deployCreate3(salt, initCode);

        console.logString("Simulation Router Executor Address :");
        console.logAddress(actualAddr);

        if (privateRouterExecutor != actualAddr) {
            revert("Create 3 addresses don't match.");
        }

        vm.stopBroadcast();
    }
}
