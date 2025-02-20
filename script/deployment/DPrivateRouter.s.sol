// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

import {CreateXScript} from "./CreateXScript.sol";
import {ICreateX} from "./interfaces/ICreateX.sol";
import {ArrakisRoles} from "./constants/ArrakisRoles.sol";
import {WethFactory} from "./constants/WethFactory.sol";

import {ArrakisPrivateVaultRouter} from
    "../../src/ArrakisPrivateVaultRouter.sol";
import {NATIVE_COIN} from "../../src/constants/CArrakis.sol";

// Private Router Test : 0x42dEa2a3911F287391f7B4c97dF12912A5831189
// Private Router : 0xEa9702Cf19BB348F17155E92357beF1Ed6F080B3
contract DPrivateRouter is CreateXScript {
    uint88 public version = uint88(
        uint256(keccak256(abi.encode("Private Router version 1")))
    );

    address public constant factory =
        0x820FB8127a689327C863de8433278d6181123982;
    address public constant permit2 =
        0x000000000022D473030F116dDEE9F6B43aC78BA3;

    function setUp() public {}

    function run() public {
        address weth = WethFactory.getWeth();

        console.logString("WETH :");
        console.logAddress(weth);

        vm.startBroadcast();

        address owner = msg.sender;

        console.logString("Deployer :");
        console.logAddress(msg.sender);

        bytes memory initCode = abi.encodePacked(
            type(ArrakisPrivateVaultRouter).creationCode,
            abi.encode(NATIVE_COIN, permit2, owner, factory, weth)
        );

        bytes32 salt = bytes32(
            abi.encodePacked(msg.sender, hex"00", bytes11(version))
        );

        address router = computeCreate3Address(salt, msg.sender);

        console.logString("Private Router Address : ");
        console.logAddress(router);

        address actualAddr = CreateX.deployCreate3(salt, initCode);

        console.logString("Simulation Address :");
        console.logAddress(actualAddr);

        if (router != actualAddr) {
            revert("Create 3 addresses don't match.");
        }

        vm.stopBroadcast();
    }
}
