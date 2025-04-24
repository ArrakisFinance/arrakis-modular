// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

import {CreateXScript} from "./CreateXScript.sol";
import {ICreateX} from "./interfaces/ICreateX.sol";

import {WithdrawHelper} from "../../src/utils/WithdrawHelper.sol";

// WithdrawHelper : 0x3F99b26DE263d4436e114e6De54e4DE55D41BD2d.
// base, arbitrum, mainnet, optimism, polygon, sepolia, ink, unichain
contract DWithdrawHelper is CreateXScript {
    uint88 public version = uint88(
        uint256(
            keccak256(abi.encode("Withdraw Helper version 1"))
        )
    );

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        console.logString("Deployer :");
        console.logAddress(msg.sender);

        bytes memory initCode = abi.encodePacked(
            type(WithdrawHelper).creationCode
        );

        bytes32 salt = bytes32(
            abi.encodePacked(msg.sender, hex"00", bytes11(version))
        );

        address implementation = computeCreate3Address(salt, msg.sender);

        console.logString("Withdraw Helper Address : ");
        console.logAddress(implementation);

        address actualAddr = CreateX.deployCreate3(salt, initCode);

        console.logString("Actual Withdraw Helper Address :");
        console.logAddress(actualAddr);

        if (actualAddr != implementation) {
            revert("Create 3 addresses don't match.");
        }

        vm.stopBroadcast();
    }
}
