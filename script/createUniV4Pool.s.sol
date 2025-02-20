// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";
import {CreateXScript} from "./deployment/CreateXScript.sol";

import {IPoolManager} from
    "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {StateLibrary} from
    "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {
    PoolKey, Currency
} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {
    CurrencyLibrary
} from "@uniswap/v4-core/src/types/Currency.sol";
import {
    PoolId,
    PoolIdLibrary
} from "@uniswap/v4-core/src/types/PoolId.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IUniswapV3 {
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        );
}

// IMPORTANT !!! Fill in / check these sensitive varaibles before running script !!!

address constant poolManager =
    0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32; // arbitrum eth/usdc
address constant GEL = 0x15b7c0c907e4C6b9AdaAaabC300C08991D6CEA05;
address constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
address constant USDC = 0xF1815bd50389c46847f0Bda824eC8da914045D14;
uint24 constant fee = 10000;
int24 constant tickSpacing = 200;
// address constant hooks = address(0);
// uint160 constant sqrtPrice = 1273116126588280379470247060237456;
int24 constant tick = 0;

address constant V3Pool = 
    0x2dd31cc03Ed996A99Fbfdffa07f8f4604B1a2eC1;

contract CreateUniV4Pool is CreateXScript {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    uint88 public constant version = uint88(
        uint256(keccak256(abi.encode("Private Hook GEL/WETH Mainnet")))
    );

    function setUp() public {}

    function run() public {

        vm.startBroadcast();

        console.log(msg.sender);

        // (uint160 sqrtPrice,,,,,,) = IUniswapV3(V3Pool).slot0();
        uint160 sqrtPrice = 4108373974895214211729642;

        // bytes32 salt = bytes32(
        //     abi.encodePacked(msg.sender, hex"00", bytes11(version))
        // );

        // address hookAddr = computeCreate3Address(salt, msg.sender);

        PoolKey memory poolKey = PoolKey({
            currency0: CurrencyLibrary.ADDRESS_ZERO,
            currency1: Currency.wrap(USDC),
            fee: fee,
            tickSpacing: tickSpacing,
            hooks: IHooks(address(0))
        });

        PoolId poolId = poolKey.toId();

        console.log("Pool Id : ");
        console.logBytes32(PoolId.unwrap(poolId));

        // (
        //     uint160 sqrtPriceX96,
        //     int24 t,
        //     uint24 protocolFee,
        //     uint24 lpFee
        // ) = IPoolManager(poolManager).getSlot0(poolId);

        // console.log("Sqrt Price : ", sqrtPriceX96);
        // console.logInt(t);
        // console.log("Protocol Fee : ", protocolFee);
        // console.log("LP Fee : ", lpFee);

        // #region pool creation.

        int24 tick = IPoolManager(poolManager).initialize(poolKey, sqrtPrice);

        console.logInt(tick);

        // #endregion pool creation.

        // (
        //     sqrtPriceX96,
        //     tick,
        //     protocolFee,
        //     lpFee
        // ) = IPoolManager(poolManager).getSlot0(poolId);

        // console.log("Sqrt Price : ", sqrtPriceX96);
        // console.logInt(tick);
        // console.log("Protocol Fee : ", protocolFee);
        // console.log("LP Fee : ", lpFee);

        vm.stopBroadcast();
    }
}
