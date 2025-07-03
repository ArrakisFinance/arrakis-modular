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

// #region shadow deployment.

// #region bsc.

// PancakeSwapV4StandardModulePrivate : 0x999b23eAA5BCF2Ff246fc979c80D729812541d64.
// UpgradeableBeacon : 0xC164893891d312876C8B0A59811DB096f8a740Cc.

// #endregion bsc.

// #endregion shadow deployment.

// #region production deployment.

// #region Binance smart chain.

// PancakeSwapV4StandardModulePrivate : 0xac5e63C470007B24b15Be5BBc0462600F5Ebc265.
// UpgradeableBeacon : 0xE137AeED8783D04fBa9c9Df89aEcCEE81468cE58.
// PancakeSwap V4 : 0xf7Db3EFaF9EAFF43a3f0715E681B1FDD1CE6F1Aa.
// PancakeSwap V4 Underlying : 0x6dE10E47fF85884CA08b55FD123DD2C14A189aD2.

// #endregion Binance smart chain.

// #endregion production deployment.

contract DPancakeSwapV4StandardModulePrivate is CreateXScript {
    uint88 public version = uint88(
        uint256(
            keccak256(
                abi.encode(
                    "Pancake Standard Private Module version 1.0.0"
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

    address public constant collector = address(1);

    function setUp() public {}

    function run() public {
        address poolManager = getPoolManager();
        address pancakeVault = getPancakeVault();

        vm.startBroadcast();

        console.logString("Deployer :");
        console.logAddress(msg.sender);

        bytes memory initCode = abi.encodePacked(
            type(PancakeSwapV4StandardModulePrivate).creationCode,
            abi.encode(
                poolManager,
                guardian,
                pancakeVault,
                distributor,
                collector
            )
        );

        bytes32 salt = bytes32(
            abi.encodePacked(msg.sender, hex"00", bytes11(version))
        );

        address pancakeSwapV4StandardPrivate =
            computeCreate3Address(salt, msg.sender);

        console.logString(
            "Pancake Swap V4 Standard Module Private Implementation Address : "
        );
        console.logAddress(pancakeSwapV4StandardPrivate);

        address actualAddr = CreateX.deployCreate3(salt, initCode);

        console.logString("Simulation Address :");
        console.logAddress(actualAddr);

        if (pancakeSwapV4StandardPrivate != actualAddr) {
            revert("Create 3 addresses don't match.");
        }

        address upgradeableBeacon =
            address(new UpgradeableBeacon(pancakeSwapV4StandardPrivate));

        UpgradeableBeacon(upgradeableBeacon).transferOwnership(
            arrakisTimeLock
        );

        console.logString(
            "Upgradeable Beacon Uniswap V4 Private Address : "
        );
        console.logAddress(upgradeableBeacon);

        vm.stopBroadcast();
    }

    function getPoolManager() public view returns (address) {
        uint256 chainId = block.chainid;

        // binance smart chain
        if (chainId == 56) {
            return 0xa0FfB9c1CE1Fe56963B0321B32E7A0302114058b;
        } else {
            revert("Not Supported Chain Id");
        }
    }

    function getPancakeVault() public view returns (address) {
        uint256 chainId = block.chainid;

        // binance smart chain
        if (chainId == 56) {
            return 0x238a358808379702088667322f80aC48bAd5e6c4;
        } else {
            revert("Not Supported Chain Id");
        }
    }
}
