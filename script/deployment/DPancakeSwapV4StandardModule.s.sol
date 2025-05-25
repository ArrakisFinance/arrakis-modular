// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {console} from "forge-std/console.sol";

import {CreateXScript} from "./CreateXScript.sol";
import {ICreateX} from "./interfaces/ICreateX.sol";
import {ArrakisRoles} from "./constants/ArrakisRoles.sol";

import {PancakeSwapV4StandardModulePrivate} from
    "../../src/modules/PancakeSwapV4StandardModulePrivate.sol";

import {UpgradeableBeacon} from
    "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

// #region Binance.

// Binance Pancake Underlying V4 : 0x1acE2A6a905cc033D89A58fb4247eB20f8EBD2dB
// Binance Pancake V4 : 0x6aA371b4859CD58171794892709Dd43Da2D4EBDE
// Binance UniswapV4StandardPrivate : 0x999b23eAA5BCF2Ff246fc979c80D729812541d64.
// Binance UpgradeableBeacon : 0xC164893891d312876C8B0A59811DB096f8a740Cc

// #endregion Binance.

contract DPancakeSwapV4StandardModule is CreateXScript {
    uint88 public version = uint88(
        uint256(
            keccak256(
                abi.encode(
                    "Pancake Swap V4 Standard Private Module version beta 1.0.0"
                )
            )
        )
    );

    address public constant guardian =
        0x6F441151B478E0d60588f221f1A35BcC3f7aB981;

    address public constant arrakisTimeLock =
        0xAf6f9640092cB1236E5DB6E517576355b6C40b7f;

    address public constant distributor =
        0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae;

    function setUp() public {}

    function run() public {
        address poolManager = getCLPoolManager();
        address vault = getVault();
        address owner = ArrakisRoles.getOwner();

        vm.startBroadcast();

        console.logString("Deployer :");
        console.logAddress(msg.sender);

        // bytes memory initCode = abi.encodePacked(
        //     type(PancakeSwapV4StandardModulePrivate).creationCode,
        //     abi.encode(poolManager, guardian, vault, distributor, owner)
        // );

        // bytes32 salt = bytes32(
        //     abi.encodePacked(msg.sender, hex"00", bytes11(version))
        // );

        // address uniswapV4StandardPrivate =
        //     computeCreate3Address(salt, msg.sender);

        // console.logString(
        //     "Uniswap V4 Standard Module Private Implementation Address : "
        // );
        // console.logAddress(uniswapV4StandardPrivate);

        // address actualAddr = CreateX.deployCreate3(salt, initCode);

        // console.logString("Simulation Address :");
        // console.logAddress(actualAddr);

        // if (uniswapV4StandardPrivate != actualAddr) {
        //     revert("Create 3 addresses don't match.");
        // }

        address upgradeableBeacon =
            address(new UpgradeableBeacon(0x999b23eAA5BCF2Ff246fc979c80D729812541d64));

        UpgradeableBeacon(upgradeableBeacon).transferOwnership(
            arrakisTimeLock
        );

        // console.logString(
        //     "Upgradeable Beacon Uniswap V4 Private Address : "
        // );
        // console.logAddress(upgradeableBeacon);

        vm.stopBroadcast();
    }

    function getCLPoolManager() public view returns (address) {
        uint256 chainId = block.chainid;

        // binance
        if (chainId == 56) {
            return 0xa0FfB9c1CE1Fe56963B0321B32E7A0302114058b;
        }
        // Not Supported
        else  {
            revert("Chain ID not supported.");
        }
    }

    function getVault() public view returns (address) {
        uint256 chainId = block.chainid;

        // binance
        if (chainId == 56) {
            return 0x238a358808379702088667322f80aC48bAd5e6c4;
        }
        // Not Supported
        else  {
            revert("Chain ID not supported.");
        }
    }
}