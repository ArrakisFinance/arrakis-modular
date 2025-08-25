// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

import {CreateXScript} from "./CreateXScript.sol";
import {ICreateX} from "./interfaces/ICreateX.sol";

import {
    AerodromeRewardsViewer
} from "../../src/utils/AerodromeRewardsViewer.sol";

// #region Base.

// Aerodrome Rewards Viewer : 0x81a07986648A3d9E061f07c136D8AbB7dbAeC7C4

// #endregion Base.

contract DAerodromeRewardsViewer is CreateXScript {
    uint88 public version = uint88(
        uint256(
            keccak256(abi.encode("Aerodrome Rewards Viewer beta version"))
        )
    );

    // address public constant nftPositionManager =

    address public constant AERO = 0x940181a94A35A4569E4529A3CDfB74e38FD98631;
    bytes32 public constant MODULE_ID = 0x491defc0794897991a8e5e9fa49dcbed24fe84ee079750b1db3f4df77fb17cb5;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        console.logString("Deployer :");
        console.logAddress(msg.sender);

        bytes memory initCode = abi.encodePacked(
            type(AerodromeRewardsViewer).creationCode,
            abi.encode(
                AERO,
                MODULE_ID
            )
        );

        bytes32 salt = bytes32(
            abi.encodePacked(msg.sender, hex"00", bytes11(version))
        );

        address aeroRewardsViewer = computeCreate3Address(salt, msg.sender);

        console.logString(
            "Aerodrome Rewards Viewer Implementation Address : "
        );
        console.logAddress(aeroRewardsViewer);

        address actualAddr = CreateX.deployCreate3(salt, initCode);

        console.logString("Simulation Address :");
        console.logAddress(actualAddr);

        if (aeroRewardsViewer != actualAddr) {
            revert("Create 3 addresses don't match.");
        }

        vm.stopBroadcast();
    }
}
