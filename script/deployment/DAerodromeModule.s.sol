// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.19;

// import {console} from "forge-std/console.sol";

// import {CreateXScript} from "./CreateXScript.sol";
// import {ICreateX} from "./interfaces/ICreateX.sol";
// import {ArrakisRoles} from "./constants/ArrakisRoles.sol";

// import {
//     AerodromeStandardModulePrivate,
//     INonfungiblePositionManager,
//     IUniswapV3Factory,
//     IVoter
// } from "../../src/modules/AerodromeStandardModulePrivate.sol";

// import {UpgradeableBeacon} from
//     "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

// // #region test.

// //   Aerodrome Module Implementation Address : 
// //   0xc2c26729f55eBe48B392e8aBD0a6f2174e1104d6
// //   Upgradeable Beacon Aerodrome Address : 
// //   0x06419faACEA3238244E71aBaBDC42B420a66F7E2

// // #endregion

// contract DAerodromeModule is CreateXScript {
//     uint88 public version = uint88(
//         uint256(
//             keccak256(abi.encode("Aerodrome Module version Beta 2"))
//         )
//     );

//     // address public constant nftPositionManager =

//     address public constant nftPositionManager =
//         0x827922686190790b37229fd06084350E74485b72;

//     address public constant factory =
//         0x5e7BB104d84c7CB9B682AaC2F3d509f5F406809A;

//     address public constant voter =
//         0x16613524e02ad97eDfeF371bC883F2F5d6C480A5;

//     address public constant guardian =
//         0x6F441151B478E0d60588f221f1A35BcC3f7aB981;

//     address public constant arrakisTimeLock =
//         0xAf6f9640092cB1236E5DB6E517576355b6C40b7f;

//     function setUp() public {}

//     function run() public {
//         uint256 privateKey = vm.envUint("PK_TEST");

//         address deployer = vm.addr(privateKey);

//         console.logString("Deployer :");
//         console.logAddress(deployer);

//         vm.startBroadcast();

//         bytes memory initCode = abi.encodePacked(
//             type(AerodromeStandardModulePrivate).creationCode,
//             abi.encode(
//                 nftPositionManager,
//                 factory,
//                 voter,
//                 guardian
//             )
//         );

//         bytes32 salt = bytes32(
//             abi.encodePacked(deployer, hex"00", bytes11(version))
//         );

//         address aeroModule = computeCreate3Address(salt, deployer);

//         console.logString(
//             "Aerodrome Module Implementation Address : "
//         );
//         console.logAddress(aeroModule);

//         address actualAddr = CreateX.deployCreate3(salt, initCode);

//         console.logString("Simulation Address :");
//         console.logAddress(actualAddr);

//         if (aeroModule != actualAddr) {
//             revert("Create 3 addresses don't match.");
//         }

//         address upgradeableBeacon =
//             address(new UpgradeableBeacon(aeroModule));

//         UpgradeableBeacon(upgradeableBeacon).transferOwnership(
//             arrakisTimeLock
//         );

//         console.logString("Upgradeable Beacon Aerodrome Address : ");
//         console.logAddress(upgradeableBeacon);

//         vm.stopBroadcast();
//     }
// }
