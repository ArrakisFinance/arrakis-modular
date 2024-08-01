// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

import {CreateXScript} from "./CreateXScript.sol";
import {ICreateX} from "./interfaces/ICreateX.sol";
import {ArrakisRoles} from "./constants/ArrakisRoles.sol";
import {CREATEX_ADDRESS} from "./constants/CCreateX.sol";

import {ArrakisPublicVaultRouter} from
    "../../src/ArrakisPublicVaultRouter.sol";
import {NATIVE_COIN} from "../../src/constants/CArrakis.sol";

contract DRouter is CreateXScript {
    uint88 public version =
        uint88(uint256(keccak256(abi.encode("Router version 1"))));

    address public constant factory =
        0x1209BD3e8fAf1d142D925B4edaCc30c296d22bf1;
    address public constant permit2 =
        0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address public constant weth =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    function setUp() public {}

    function run() public {
        // owner multisig can do the deploymenet.
        // owner will also be the owner of guardian.
        address deployer = ArrakisRoles.getOwner();

        address owner = deployer;

        console.logString("Deployer :");
        console.logAddress(deployer);

        bytes memory initCode = abi.encodePacked(
            type(ArrakisPublicVaultRouter).creationCode,
            abi.encode(NATIVE_COIN, permit2, owner, factory, weth)
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

        address router = computeCreate3Address(salt, deployer);

        console.logString("Router Address : ");
        console.logAddress(router);

        vm.prank(deployer);

        address actualAddr = CreateX.deployCreate3(salt, initCode);

        console.logString("Simulation Address :");
        console.logAddress(actualAddr);

        if (router != actualAddr) {
            revert("Create 3 addresses don't match.");
        }
    }
}
