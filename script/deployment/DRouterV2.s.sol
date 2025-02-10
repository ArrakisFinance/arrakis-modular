// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

import {CreateXScript} from "./CreateXScript.sol";
import {ICreateX} from "./interfaces/ICreateX.sol";
import {ArrakisRoles} from "./constants/ArrakisRoles.sol";
import {WethFactory} from "./constants/WethFactory.sol";

import {ArrakisPublicVaultRouterV2} from
    "../../src/ArrakisPublicVaultRouterV2.sol";
import {NATIVE_COIN} from "../../src/constants/CArrakis.sol";

// Router V2 : 0x64c3ac1a917953c99ea6a37c8aa8c534b32eb780
contract DRouterV2 is CreateXScript {
    uint88 public version =
        uint88(uint256(keccak256(abi.encode("RouterV2 version 1"))));

    address public constant factory =
        0x820FB8127a689327C863de8433278d6181123982;
    address public constant permit2 =
        0x000000000022D473030F116dDEE9F6B43aC78BA3;

    function setUp() public {}

    function run() public {
        uint256 privateKey = vm.envUint("PK_TEST");

        address deployer = vm.addr(privateKey);

        address owner = ArrakisRoles.getOwner();

        address weth = WethFactory.getWeth();

        console.logString("WETH :");
        console.logAddress(weth);

        console.logString("Deployer :");
        console.logAddress(deployer);

        vm.startBroadcast(privateKey);

        bytes memory initCode = abi.encodePacked(
            type(ArrakisPublicVaultRouterV2).creationCode,
            abi.encode(NATIVE_COIN, permit2, owner, factory, weth)
        );

        bytes32 salt = bytes32(
            abi.encodePacked(deployer, hex"00", bytes11(version))
        );

        bytes memory payload = abi.encodeWithSelector(
            ICreateX.deployCreate3.selector, salt, initCode
        );

        address router = computeCreate3Address(salt, deployer);

        console.logString("Router V2 Address : ");
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
