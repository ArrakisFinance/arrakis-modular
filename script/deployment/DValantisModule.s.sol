// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

import {CreateXScript} from "./CreateXScript.sol";
import {ICreateX} from "./interfaces/ICreateX.sol";
import {ArrakisRoles} from "./constants/ArrakisRoles.sol";

import {ValantisModulePublic} from
    "../../src/modules/ValantisHOTModulePublic.sol";

import {UpgradeableBeacon} from
    "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

// Valantis Module Implementation : 0x9Ac1249E37EE1bDc38dC0fF873F1dB0c5E6aDdE3
// Mainnet UpgradeableBeacon : 0xE973Cf1e347EcF26232A95dBCc862AA488b0351b
// Base UpgradeableBeacon : 0xCc8989978668ad377369C0cC720192377a6006e3
// Arbitrum UpgradeableBeacon : 0x64865e4656660FC6fC2839998d8946e4701479AC
// Sepolia UpgradeableBeacon : 0xFb4e25800b77BcD09227729FFCC145685797f408
contract DValantisModule is CreateXScript {
    uint88 public version = uint88(
        uint256(keccak256(abi.encode("Valantis Module version 1")))
    );

    address public constant guardian =
        0x6F441151B478E0d60588f221f1A35BcC3f7aB981;

    address public constant arrakisTimeLock =
        0xAf6f9640092cB1236E5DB6E517576355b6C40b7f;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        console.logString("Deployer :");
        console.logAddress(msg.sender);

        bytes memory initCode = abi.encodePacked(
            type(ValantisModulePublic).creationCode,
            abi.encode(guardian)
        );

        bytes32 salt = bytes32(
            abi.encodePacked(msg.sender, hex"00", bytes11(version))
        );

        address valantisModuleImpl =
            computeCreate3Address(salt, msg.sender);

        console.logString("Valantis Module Implementation Address : ");
        console.logAddress(valantisModuleImpl);

        address actualAddr = CreateX.deployCreate3(salt, initCode);

        console.logString("Simulation Address :");
        console.logAddress(actualAddr);

        if (valantisModuleImpl != actualAddr) {
            revert("Create 3 addresses don't match.");
        }

        address upgradeableBeacon =
            address(new UpgradeableBeacon(valantisModuleImpl));

        UpgradeableBeacon(upgradeableBeacon).transferOwnership(
            arrakisTimeLock
        );

        console.logString("Upgradeable Beacon Valantis Address : ");
        console.logAddress(upgradeableBeacon);

        vm.stopBroadcast();
    }
}
