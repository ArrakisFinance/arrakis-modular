// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.19;

// import {Script} from "forge-std/Script.sol";
// import {console} from "forge-std/console.sol";

// import {IArrakisMetaVaultFactory} from
//     "../src/interfaces/IArrakisMetaVaultFactory.sol";
// import {IAerodromeStandardModulePrivate} from
//     "../src/interfaces/IAerodromeStandardModulePrivate.sol";
// import {IOracleWrapper} from "../src/interfaces/IOracleWrapper.sol";
// import {PIPS} from "../src/constants/CArrakis.sol";
// import {IVoter} from "../src/interfaces/IVoter.sol";
// import {IUniswapV3Factory} from
//     "../src/interfaces/IUniswapV3Factory.sol";
// import {IUniswapV3Pool} from "../src/interfaces/IUniswapV3Pool.sol";

// import {
//     PoolKey, Currency
// } from "@uniswap/v4-core/src/types/PoolKey.sol";
// import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";

// /// @dev before this script we should whitelist the deployer as public vault deployer using the multisig
// /// on the factory side.

// bytes32 constant salt =
//     keccak256(abi.encode("Salt WETH/USDC Aero vault Private Test 7"));
// // address constant token0 = 0xb4116a6069f22E4a88AE3a06d52346c14f155186;
// // address constant token1 = 0xC97Bcf1e3B3283A71F0739796EE0A010E667187C;
// address constant vaultOwner =
//     0xE652c76246d3b0832E95200f03CD90E314192972;

// uint24 constant maxSlippage = PIPS / 50;

// uint24 constant maxDeviation = PIPS / 50;
// uint256 constant cooldownPeriod = 60;
// address constant executor = 0xe012b59a8fC2D18e2C8943106a05C2702640440B;
// address constant stratAnnouncer =
//     0xE652c76246d3b0832E95200f03CD90E314192972;

// address constant aeroPrivateUpgradeableBeacon =
//     0x8Dd906EcF9D434A3fBf2d60a14Fbf73d14d4Ea6e;
// address constant factory = 0x820FB8127a689327C863de8433278d6181123982;
// address constant oracle = 0x238BBdba282298a7243A8F8Cd84800a81f0C6c96;
// address constant aeroReceiver =
//     0xE652c76246d3b0832E95200f03CD90E314192972;

// // address constant clpool = 0xeD1A4B659197f1829324161E7E2bF029061D22cB;
// address constant clfactory =
//     0x5e7BB104d84c7CB9B682AaC2F3d509f5F406809A;
// address constant voter = 0x16613524e02ad97eDfeF371bC883F2F5d6C480A5;

// address constant token0 = 0x4200000000000000000000000000000000000006;
// address constant token1 = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
// int24 constant tickSpacing = 100;
// int24 constant newTickSpacing = 2000;

// // oracle : 0x238BBdba282298a7243A8F8Cd84800a81f0C6c96

// contract AerodromeVaultOnePrivate is Script {
//     function setUp() public {}

//     function run() public {
//         uint256 privateKey = vm.envUint("PK_TEST");

//         address account = vm.addr(privateKey);

//         console.logString("Deployer : ");
//         console.logAddress(account);

//         vm.startBroadcast();

//         // #region get pool price.

//         address currentPool = IUniswapV3Factory(clfactory).getPool(
//             token0, token1, tickSpacing
//         );

//         // (uint160 sqrtPriceX96,,,,,) = IUniswapV3Pool(currentPool).slot0();

//         // console.log("Sqrt Price : ", sqrtPriceX96);

//         // #endregion get pool price.

//         address pool = IUniswapV3Factory(clfactory).getPool(
//             token0,
//             token1,
//             newTickSpacing
//         );

//         console.log("Pool Address : ");
//         console.logAddress(pool);

//         // address gaugeAddr = IVoter(voter).createGauge(clfactory, pool);

//         // console.logString("Gauge Address : ");
//         // console.logAddress(gaugeAddr);

//         bytes memory moduleCreationPayload = abi.encodeWithSelector(
//             IAerodromeStandardModulePrivate.initialize.selector,
//             IOracleWrapper(oracle),
//             maxSlippage,
//             aeroReceiver,
//             newTickSpacing
//         );
//         bytes memory initManagementPayload = abi.encode(
//             IOracleWrapper(oracle),
//             maxDeviation,
//             cooldownPeriod,
//             executor,
//             stratAnnouncer,
//             maxSlippage
//         );

//         address vault = IArrakisMetaVaultFactory(factory)
//             .deployPrivateVault(
//             salt,
//             token0,
//             token1,
//             vaultOwner,
//             aeroPrivateUpgradeableBeacon,
//             moduleCreationPayload,
//             initManagementPayload
//         );

//         console.logString("Aerodrome Private Vault Address : ");
//         console.logAddress(vault);

//         vm.stopBroadcast();
//     }
// }
