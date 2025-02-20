// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.19;

// import {console} from "forge-std/console.sol";

// import {CreateXScript} from "./deployment/CreateXScript.sol";
// import {ICreateX} from "./deployment/interfaces/ICreateX.sol";
// import {ArrakisRoles} from "./deployment/constants/ArrakisRoles.sol";

// import {IUniswapV3Factory} from "../src/interfaces/IUniswapV3Factory.sol";

// import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// // IMPORTANT !!! Fill in / check these sensitive varaibles before running script !!!

// address constant factory = 0x5e7BB104d84c7CB9B682AaC2F3d509f5F406809A; // arbitrum eth/usdc
// address constant token0 = 0xb4116a6069f22E4a88AE3a06d52346c14f155186;
// address constant token1 = 0xC97Bcf1e3B3283A71F0739796EE0A010E667187C;
// int24 constant tickSpacing = 100;
// uint160 constant sqrtPrice =
//     4519207396655637384660017;

// address constant tester = 0x8e1E26a99F060633f73a736c8cF8dFAa56a0b6e6;

// uint88 constant wethVersion =
//     uint88(uint256(keccak256(abi.encode("USDC version 1"))));

// uint88 constant usdcVersion =
//     uint88(uint256(keccak256(abi.encode("WETH version 1"))));

// // #region ERC20 mock token.

// contract USDC is ERC20 {
//     constructor() ERC20("USDC", "USDC") {
//         _mint(tester, 100_000_000_000e6);
//     }

//     function decimals() public pure override returns (uint8) {
//         return 6;
//     }
// }

// contract WETH is ERC20 {
//     constructor() ERC20("WETH", "WETH") {
//         _mint(tester, 120_000_000e18);
//     }
// }

// // #endregion ERC20 mock token.

// contract CreateAerodromePool is CreateXScript {
//     function setUp() public {}

//     function run() public {
//         uint256 privateKey = vm.envUint("PK_TEST");

//         address account = vm.addr(privateKey);

//         console.log(account);

//         vm.startBroadcast();

//         // deployUSDCMock(account);
//         // deployWETHMock(account);

//         // #region create pool.

//         address pool = IUniswapV3Factory(factory).createPool(
//             token0,
//             token1,
//             tickSpacing,
//             sqrtPrice
//         );

//         console.logAddress(pool);

//         // #endregion create pool.

//         vm.stopBroadcast();
//     }

//     function deployUSDCMock(
//         address deployer_
//     ) public {
//         bytes memory initCode =
//             abi.encodePacked(type(USDC).creationCode);

//         bytes32 salt = bytes32(
//             abi.encodePacked(deployer_, hex"00", bytes11(usdcVersion))
//         );

//         address usdcToken = computeCreate3Address(salt, deployer_);

//         console.logString("USDC Address : ");
//         console.logAddress(usdcToken);

//         address actualUSDCAddr = CreateX.deployCreate3(salt, initCode);

//         console.logString("Simulation Address :");
//         console.logAddress(actualUSDCAddr);

//         if (actualUSDCAddr != usdcToken) {
//             revert("Create 3 addresses don't match.");
//         }
//     }

//     function deployWETHMock(
//         address deployer_
//     ) public {
//         bytes memory initCode =
//             abi.encodePacked(type(WETH).creationCode);

//         bytes32 salt = bytes32(
//             abi.encodePacked(deployer_, hex"00", bytes11(wethVersion))
//         );

//         address wethToken = computeCreate3Address(salt, deployer_);

//         console.logString("WETH Address : ");
//         console.logAddress(wethToken);

//         address actualWETHAddr = CreateX.deployCreate3(salt, initCode);

//         console.logString("Simulation Address :");
//         console.logAddress(actualWETHAddr);

//         if (actualWETHAddr != wethToken) {
//             revert("Create 3 addresses don't match.");
//         }
//     }
// }
