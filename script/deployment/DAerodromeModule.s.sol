// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.19;

// import {console} from "forge-std/console.sol";

// import {CreateXScript} from "./CreateXScript.sol";
// import {ICreateX} from "./interfaces/ICreateX.sol";
// import {ArrakisRoles} from "./constants/ArrakisRoles.sol";

// import {AerodromeStandardModulePrivate} from
//     "../../src/modules/AerodromeStandardModulePrivate.sol";

// import {UpgradeableBeacon} from
//     "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

// // Base test implementation : 0x0472C68b8945516c125366C4D95AAf1043171410.
// // Base test Upgreadable Beacon : 0x8Dd906EcF9D434A3fBf2d60a14Fbf73d14d4Ea6e.
// contract DAerodromeModule is CreateXScript {
//     uint88 public version = uint88(
//         uint256(
//             keccak256(abi.encode("Aerodrome Module version Test 1"))
//         )
//     );

//     address public constant guardian =
//         0x6F441151B478E0d60588f221f1A35BcC3f7aB981;

//     address public constant arrakisTimeLock =
//         0xAf6f9640092cB1236E5DB6E517576355b6C40b7f;

//     address public nftPositionManager =
//         0x827922686190790b37229fd06084350E74485b72;
//     address public clFactory =
//         0x5e7BB104d84c7CB9B682AaC2F3d509f5F406809A;
//     address public voter = 0x16613524e02ad97eDfeF371bC883F2F5d6C480A5;

//     function setUp() public {}

//     function run() public {
//         uint256 privateKey = vm.envUint("PK_TEST");

//         address deployer = vm.addr(privateKey);

//         console.logString("Deployer :");
//         console.logAddress(deployer);

//         vm.startBroadcast();

//         bytes memory initCode = abi.encodePacked(
//             type(AerodromeStandardModulePrivate).creationCode,
//             abi.encode(nftPositionManager, clFactory, voter, guardian)
//         );

//         bytes32 salt = bytes32(
//             abi.encodePacked(deployer, hex"00", bytes11(version))
//         );

//         address aerodromeModuleImpl =
//             computeCreate3Address(salt, deployer);

//         console.logString("Aerodrome Module Implementation Address : ");
//         console.logAddress(aerodromeModuleImpl);

//         address actualAddr = CreateX.deployCreate3(salt, initCode);

//         console.logString("Simulation Address :");
//         console.logAddress(actualAddr);

//         if (aerodromeModuleImpl != actualAddr) {
//             revert("Create 3 addresses don't match.");
//         }

//         address upgradeableBeacon =
//             address(new UpgradeableBeacon(aerodromeModuleImpl));

//         UpgradeableBeacon(upgradeableBeacon).transferOwnership(
//             arrakisTimeLock
//         );

//         console.logString("Upgradeable Beacon Valantis Address : ");
//         console.logAddress(upgradeableBeacon);

//         vm.stopBroadcast();
//     }
// }
