// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {console} from "forge-std/console.sol";

import {CreateXScript} from "./CreateXScript.sol";
import {ICreateX} from "./interfaces/ICreateX.sol";
import {ArrakisRoles} from "./constants/ArrakisRoles.sol";

import {UnderlyingV4} from "../../src/libraries/UnderlyingV4.sol";
import {UniV4StandardModulePrivate} from
    "../../src/modules/UniV4StandardModulePrivate.sol";

import {UpgradeableBeacon} from
    "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

// Sepolia Uniswap V4 Standard Module Private : 0x189aFA46b68e61f0b1cBa803B5087F4fEbF954F8.
// Sepolia Ugradeable Beacon : 0xc0b7fac163566a768b4f30d06fd4b08bb6b987f0.

// #region Mainnet.

// Mainnet Underlying V4 : 0xB2BA4B781EB2e575A928E54c404b67b904A4DBEb
// Mainnet Uniswap V4 : 0x2Aa0f3154D1e7109AaF681A372589DA318B2BA56
// Mainnet UniswapV4StandardPrivate : 0x04eAd25447F9371c5c1e2C33645f32aAFEb337dc.
// Mainnet UpgradeableBeacon : 0x022a0C7dc85Fc3fF81f9f8Ef65Ae2813A062F556

// #endregion Mainnet.

// #region Polygon.

// Polygon Underlying V4 : 0xB2BA4B781EB2e575A928E54c404b67b904A4DBEb
// Polygon Uniswap V4 : 0x2Aa0f3154D1e7109AaF681A372589DA318B2BA56
// Polygon UniswapV4StandardPrivate : 0x04eAd25447F9371c5c1e2C33645f32aAFEb337dc
// Polygon UpgradeableBeacon : 0xfb4e25800b77bcd09227729ffcc145685797f408.

// #endregion Polygon.

// #region Optimism.

// Optimism Underlying V4 : 0xB2BA4B781EB2e575A928E54c404b67b904A4DBEb
// Optimism Uniswap V4 : 0x2Aa0f3154D1e7109AaF681A372589DA318B2BA56
// Optimism UniswapV4StandardPrivate : 0x04eAd25447F9371c5c1e2C33645f32aAFEb337dc
// Optimism UpgradeableBeacon : 0x413fc8E6F0B95D1f45de01b17e9441ec41eD01AB

// Ink Underlying V4 : 0xB2BA4B781EB2e575A928E54c404b67b904A4DBEb
// Ink Uniswap V4 : 0x2Aa0f3154D1e7109AaF681A372589DA318B2BA56
// Ink UniswapV4StandardPrivate : 0x04eAd25447F9371c5c1e2C33645f32aAFEb337dc
// Ink UpgradeableBeacon : 0xCc8989978668ad377369C0cC720192377a6006e3

// #endregion Optimism.
contract DUniV4StandardModule is CreateXScript {
    uint88 public version = uint88(
        uint256(
            keccak256(
                abi.encode(
                    "Uniswap Standard Private Module version 1.0.0"
                )
            )
        )
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

        address poolManager = getPoolManager();

        vm.startBroadcast(privateKey);

        bytes memory initCode = abi.encodePacked(
            type(UniV4StandardModulePrivate).creationCode,
            abi.encode(poolManager, guardian)
        );

        bytes32 salt = bytes32(
            abi.encodePacked(deployer, hex"00", bytes11(version))
        );

        address uniswapV4StandardPrivate =
            computeCreate3Address(salt, deployer);

        console.logString("Uniswap V4 Standard Module Private Implementation Address : ");
        console.logAddress(uniswapV4StandardPrivate);

        address actualAddr = CreateX.deployCreate3(salt, initCode);

        console.logString("Simulation Address :");
        console.logAddress(actualAddr);

        if (uniswapV4StandardPrivate != actualAddr) {
            revert("Create 3 addresses don't match.");
        }

        address upgradeableBeacon =
            address(new UpgradeableBeacon(uniswapV4StandardPrivate));

        UpgradeableBeacon(upgradeableBeacon).transferOwnership(
            arrakisTimeLock
        );

        console.logString("Upgradeable Beacon Uniswap V4 Private Address : ");
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
        else if (chainId == 57073) {
            return 0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32;
        }
        // binance
        else if (chainId == 56) {
            return 0x28e2Ea090877bF75740558f6BFB36A5ffeE9e9dF;
        }
    }
}
