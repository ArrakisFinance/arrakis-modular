// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";
import {CreateXScript} from "./deployment/CreateXScript.sol";
import {ArrakisRoles} from "./deployment/constants/ArrakisRoles.sol";

import {IPoolManager} from
    "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {StateLibrary} from
    "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {
    PoolKey, Currency
} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {
    PoolId,
    PoolIdLibrary
} from "@uniswap/v4-core/src/types/PoolId.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {PIPS} from "../src/constants/CArrakis.sol";

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

// #region pool creation.

address constant poolManager =
    0x000000000004444c5dc75cB358380D2e3dE08A90; // arbitrum eth/usdc
address constant GEL = 0x15b7c0c907e4C6b9AdaAaabC300C08991D6CEA05;
address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
uint24 constant fee = 10_000;
int24 constant tickSpacing = 200;
// address constant hooks = address(0);
// uint160 constant sqrtPrice = 1273116126588280379470247060237456;
int24 constant tick = 0;

address constant V3Pool = 0x2dd31cc03Ed996A99Fbfdffa07f8f4604B1a2eC1;

// #endregion pool creation.

// #region private vault creation.

bytes32 constant salt =
    keccak256(abi.encode("Salt GEL/USDWETHC Uni vault Private Test"));

uint256 constant init0 = 1;
uint256 constant init1 = 1;
bool constant isInversed = false;

uint24 constant maxSlippage = PIPS / 50;
uint24 constant maxDeviation = PIPS / 50;
uint256 constant cooldownPeriod = 60;
address constant executor = 0x81a1e7F34b9bABf172087cF5df8A4DF6500e9d4d;
address constant stratAnnouncer =
    0x81a1e7F34b9bABf172087cF5df8A4DF6500e9d4d;

// #endregion private vault creation.

contract CreatePrivateHook is CreateXScript {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    uint88 public constant version = uint88(
        uint256(
            keccak256(abi.encode("Private Hook GEL/WETH Mainnet"))
        )
    );

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        console.log(msg.sender);

        address privateVaultOwner = ArrakisRoles.getOwner();

        (uint160 sqrtPrice,,,,,,) = IUniswapV3(V3Pool).slot0();

        bytes32 salt = bytes32(
            abi.encodePacked(msg.sender, hex"00", bytes11(version))
        );

        address hookAddr = computeCreate3Address(salt, msg.sender);

        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(GEL),
            currency1: Currency.wrap(WETH),
            fee: fee,
            tickSpacing: tickSpacing,
            hooks: IHooks(address(0))
        });

        PoolId poolId = poolKey.toId();

        console.log("Pool Id : ");
        console.logBytes32(PoolId.unwrap(poolId));

        (
            uint160 sqrtPriceX96,
            int24 t,
            uint24 protocolFee,
            uint24 lpFee
        ) = IPoolManager(poolManager).getSlot0(poolId);

        console.log("Sqrt Price : ", sqrtPriceX96);
        console.logInt(t);
        console.log("Protocol Fee : ", protocolFee);
        console.log("LP Fee : ", lpFee);

        // #region pool creation.

        int24 tick =
            IPoolManager(poolManager).initialize(poolKey, sqrtPrice);

        console.logInt(tick);

        // #endregion pool creation.

        (sqrtPriceX96, tick, protocolFee, lpFee) =
            IPoolManager(poolManager).getSlot0(poolId);

        console.log("Sqrt Price : ", sqrtPriceX96);
        console.logInt(tick);
        console.log("Protocol Fee : ", protocolFee);
        console.log("LP Fee : ", lpFee);

        // #region create private vault.

        // #endregion create private vault.

        vm.stopBroadcast();
    }
}
