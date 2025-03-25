// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

import {CreateXScript} from "./CreateXScript.sol";
import {ICreateX} from "./interfaces/ICreateX.sol";
import {ArrakisRoles} from "./constants/ArrakisRoles.sol";

import {BunkerModule} from "../../src/modules/BunkerModule.sol";

import {UpgradeableBeacon} from
    "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

// Bunker Module Implementation : 0xfaD5730Ade9560B8C353A717faB159f85B1b9F2f
// Mainnet UpgradeableBeacon : 0xFf0474792DEe71935a0CeF1306D93fC1DCF47BD9
// Base UpgradeableBeacon : 0x3025b46A9814a69EAf8699EDf905784Ee22C3ABB
// Arbitrum UpgradeableBeacon : 0xe25F763fa58de798AF2e454e916F527cdD17E885
// Sepolia UpgradeableBeacon : 0xB4dA34605c26BA152d465DeB885889070105BB5F
// Polygon UpgradeableBeacon : 0xD4ae05C8928d4850cDD0f800322108E6B1a8F3eB
// Optimism UpgradeableBeacon : 0x79fc92afa1ce5476010644380156790d2fc52168
// Ink UpgradeableBeacon : 0x4B6FEE838b3dADd5f0846a9f2d74081de96e6f73
// Unichain UpgradeableBeacon : 0x4B6FEE838b3dADd5f0846a9f2d74081de96e6f73
contract DBunkerModule is CreateXScript {
    uint88 public version = uint88(
        uint256(keccak256(abi.encode("Bunker Module version 1")))
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
            type(BunkerModule).creationCode, abi.encode(guardian)
        );

        bytes32 salt = bytes32(
            abi.encodePacked(msg.sender, hex"00", bytes11(version))
        );

        address bunkerModuleImpl =
            computeCreate3Address(salt, msg.sender);

        console.logString("Bunker Module Implementation Address : ");
        console.logAddress(bunkerModuleImpl);

        address actualAddr = CreateX.deployCreate3(salt, initCode);

        console.logString("Simulation Address :");
        console.logAddress(actualAddr);

        if (bunkerModuleImpl != actualAddr) {
            revert("Create 3 addresses don't match.");
        }

        address upgradeableBeacon =
            address(new UpgradeableBeacon(bunkerModuleImpl));

        UpgradeableBeacon(0x4B6FEE838b3dADd5f0846a9f2d74081de96e6f73)
            .transferOwnership(arrakisTimeLock);

        console.logString("Upgradeable Beacon Valantis Address : ");
        console.logAddress(upgradeableBeacon);

        vm.stopBroadcast();
    }
}
