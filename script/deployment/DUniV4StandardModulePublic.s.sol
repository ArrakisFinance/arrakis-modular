// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {console} from "forge-std/console.sol";

import {CreateXScript} from "./CreateXScript.sol";
import {ICreateX} from "./interfaces/ICreateX.sol";
import {ArrakisRoles} from "./constants/ArrakisRoles.sol";

import {UnderlyingV4} from "../../src/libraries/UnderlyingV4.sol";
import {UniV4StandardModulePublic} from
    "../../src/modules/UniV4StandardModulePublic.sol";

import {UpgradeableBeacon} from
    "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

// #region Sepolia deployment.

// Sepolia Underlying V4 : 0x83F3F2f0194E9BE80f836a50AAD98B115287AFad
// Sepolia Unviswap V4 : 0xE30C7F3D703392E9377C77CBC8A515c7447FC8d3
// Sepolia UniswapV4StandardPublic : 0x53f9fb26edce653320c57A88e6C34D29283fb101
// Sepolia UpgradeableBeacon : 0xBCb6702BC617298a14cbb258AE6dbaf02Bd49596.

// #endregion Sepolia deployment.

contract DUniV4StandardModulePublic is CreateXScript {
    uint88 public version = uint88(
        uint256(
            keccak256(
                abi.encode(
                    "Uniswap Standard Public Module version 1.0.0"
                )
            )
        )
    );

    address public constant guardian =
        0x6F441151B478E0d60588f221f1A35BcC3f7aB981;

    address public constant arrakisTimeLock =
        0xAf6f9640092cB1236E5DB6E517576355b6C40b7f;

    address public constant distributor =
        0x5Be2b4F6394d91a782331e0896B8613c995Ba5F5;
    // implementation address : 0x6eaB56B0C1888dC80e06C39F6B18364737205dDB

    function setUp() public {}

    function run() public {
        address poolManager = getPoolManager();

        vm.startBroadcast();

        console.logString("Deployer :");
        console.logAddress(msg.sender);

        bytes memory initCode = abi.encodePacked(
            type(UniV4StandardModulePublic).creationCode,
            abi.encode(poolManager, guardian, distributor, msg.sender)
        );

        bytes32 salt = bytes32(
            abi.encodePacked(msg.sender, hex"00", bytes11(version))
        );

        address uniswapV4StandardPublic =
            computeCreate3Address(salt, msg.sender);

        console.logString(
            "Uniswap V4 Standard Module Public Implementation Address : "
        );
        console.logAddress(uniswapV4StandardPublic);

        address actualAddr = CreateX.deployCreate3(salt, initCode);

        console.logString("Simulation Address :");
        console.logAddress(actualAddr);

        if (uniswapV4StandardPublic != actualAddr) {
            revert("Create 3 addresses don't match.");
        }

        address upgradeableBeacon =
            address(new UpgradeableBeacon(uniswapV4StandardPublic));

        UpgradeableBeacon(upgradeableBeacon).transferOwnership(
            arrakisTimeLock
        );

        console.logString(
            "Upgradeable Beacon Uniswap V4 Public Address : "
        );
        console.logAddress(upgradeableBeacon);

        vm.stopBroadcast();
    }

    function getPoolManager() public view returns (address) {
        uint256 chainId = block.chainid;

        // mainnet
        if (chainId == 1) {
            return 0x000000000004444c5dc75cB358380D2e3dE08A90;
        }
        // polygon
        else if (chainId == 137) {
            return 0x67366782805870060151383F4BbFF9daB53e5cD6;
        }
        // optimism
        else if (chainId == 10) {
            return 0x9a13F98Cb987694C9F086b1F5eB990EeA8264Ec3;
        }
        // arbitrum
        else if (chainId == 42_161) {
            return 0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32;
        }
        // sepolia
        else if (chainId == 11_155_111) {
            return 0xE03A1074c86CFeDd5C142C4F04F1a1536e203543;
        }
        // base
        else if (chainId == 8453) {
            return 0x498581fF718922c3f8e6A244956aF099B2652b2b;
        }
        // base sepolia
        else if (chainId == 84_531) {
            return 0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408;
        }
        // Ink
        else if (chainId == 57_073) {
            return 0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32;
        }
        // binance
        else if (chainId == 56) {
            return 0x28e2Ea090877bF75740558f6BFB36A5ffeE9e9dF;
        }
        // Unichain
        else if (chainId == 130) {
            return 0x1F98400000000000000000000000000000000004;
        }
    }
}
