// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.19;

// import {console} from "forge-std/console.sol";
// import {CreateXScript} from "./deployment/CreateXScript.sol";

// import {IPoolManager} from
//     "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
// import {StateLibrary} from
//     "@uniswap/v4-core/src/libraries/StateLibrary.sol";
// import {
//     PoolKey, Currency
// } from "@uniswap/v4-core/src/types/PoolKey.sol";
// import {
//     CurrencyLibrary
// } from "@uniswap/v4-core/src/types/Currency.sol";
// import {
//     PoolId,
//     PoolIdLibrary
// } from "@uniswap/v4-core/src/types/PoolId.sol";
// import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";

// import {UniV4Oracle} from "../src/oracles/UniV4Oracle.sol";

// import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";


// // IMPORTANT !!! Fill in / check these sensitive varaibles before running script !!!

// address constant poolManager =
//     0x498581fF718922c3f8e6A244956aF099B2652b2b; // arbitrum eth/usdc
// address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
// uint24 constant fee = 500;
// int24 constant tickSpacing = 10;
// // address constant hooks = address(0);
// // uint160 constant sqrtPrice = 1273116126588280379470247060237456;
// int24 constant tick = 0;

// address constant V3Pool = 
//     0x2dd31cc03Ed996A99Fbfdffa07f8f4604B1a2eC1;

// contract CreateUniV4Pool is CreateXScript {
//     using PoolIdLibrary for PoolKey;
//     using StateLibrary for IPoolManager;

//     uint88 public constant version = uint88(
//         uint256(keccak256(abi.encode("Private Hook GEL/WETH Mainnet")))
//     );

//     function setUp() public {}

//     function run() public {
//         uint256 privateKey = vm.envUint("PK_TEST");

//         address account = vm.addr(privateKey);

//         console.log(account);

//         vm.startBroadcast();


//         // (uint160 sqrtPrice,,,,,,) = IUniswapV3(V3Pool).slot0();
//         uint160 sqrtPrice = 4108373974895214211729642;

//         // bytes32 salt = bytes32(
//         //     abi.encodePacked(account, hex"00", bytes11(version))
//         // );

//         // address hookAddr = computeCreate3Address(salt, account);

//         PoolKey memory poolKey = PoolKey({
//             currency0: CurrencyLibrary.ADDRESS_ZERO,
//             currency1: Currency.wrap(USDC),
//             fee: fee,
//             tickSpacing: tickSpacing,
//             hooks: IHooks(address(0))
//         });

//         PoolId poolId = poolKey.toId();

//         console.log("Pool Id : ");
//         console.logBytes32(PoolId.unwrap(poolId));

//         // (
//         //     uint160 sqrtPriceX96,
//         //     int24 t,
//         //     uint24 protocolFee,
//         //     uint24 lpFee
//         // ) = IPoolManager(poolManager).getSlot0(poolId);

//         // console.log("Sqrt Price : ", sqrtPriceX96);
//         // console.logInt(t);
//         // console.log("Protocol Fee : ", protocolFee);
//         // console.log("LP Fee : ", lpFee);

//         // #region pool creation.

//         //address uniV4Oracle = address(new UniV4Oracle(poolKey, poolManager, true));

//         //console.logAddress(uniV4Oracle);

//         // #endregion pool creation.

//         // (
//         //     sqrtPriceX96,
//         //     tick,
//         //     protocolFee,
//         //     lpFee
//         // ) = IPoolManager(poolManager).getSlot0(poolId);

//         // console.log("Sqrt Price : ", sqrtPriceX96);
//         // console.logInt(tick);
//         // console.log("Protocol Fee : ", protocolFee);
//         // console.log("LP Fee : ", lpFee);

//         vm.stopBroadcast();
//     }
// }
