// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

import {CreateXScript} from "./CreateXScript.sol";
import {ICreateX} from "./interfaces/ICreateX.sol";
import {ArrakisRoles} from "./constants/ArrakisRoles.sol";

import {ValantisModulePrivate} from
    "../../src/modules/ValantisHOTModulePrivate.sol";

import {UpgradeableBeacon} from
    "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

// Valantis Module Implementation : 0x7E2fc9b2D37EA3E771b6F2375915b87CcA9E55bc
// Mainnet UpgradeableBeacon : 0x98e373368C3934dc220eEE8645E62f6558687bc5
// Base UpgradeableBeacon : 0x1D0c4451311A70379c59A00830E816F4cf5C6916
// Arbitrum UpgradeableBeacon : 0x52637Fb1517B7e27A98f6c09175Dcc6487e4CA9e
// Sepolia UpgradeableBeacon : 0xD2307BeD9A55742feBe560B11e090427cEa89317
contract DValantisPrivateModule is CreateXScript {
    uint88 public version = uint88(
        uint256(keccak256(abi.encode("Valantis Private Module version 1")))
    );

    address public constant guardian =
        0x6F441151B478E0d60588f221f1A35BcC3f7aB981;

    address public constant arrakisTimeLock =
        0xAf6f9640092cB1236E5DB6E517576355b6C40b7f;

    function setUp() public {}

    function run() public {
        uint256 privateKey = vm.envUint("PK_TEST");

        address deployer = vm.addr(privateKey);

        console.logString("Deployer :");
        console.logAddress(deployer);

        vm.startBroadcast(privateKey);

        bytes memory initCode = abi.encodePacked(
            type(ValantisModulePrivate).creationCode, abi.encode(guardian)
        );

        bytes32 salt = bytes32(
            abi.encodePacked(deployer, hex"00", bytes11(version))
        );

        address valantisModuleImpl = computeCreate3Address(salt, deployer);

        console.logString("Valantis Module Implementation Address : ");
        console.logAddress(valantisModuleImpl);

        address actualAddr = CreateX.deployCreate3(salt, initCode);

        console.logString("Simulation Address :");
        console.logAddress(actualAddr);

        if (valantisModuleImpl != actualAddr) {
            revert("Create 3 addresses don't match.");
        }

        address upgradeableBeacon = address(
            new UpgradeableBeacon(valantisModuleImpl)
        );

        UpgradeableBeacon(upgradeableBeacon).transferOwnership(
            arrakisTimeLock
        );

        console.logString("Upgradeable Beacon Valantis Address : ");
        console.logAddress(upgradeableBeacon);

        vm.stopBroadcast();
    }
}
