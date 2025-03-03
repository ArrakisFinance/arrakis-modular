// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";
import {CreateXScript} from "./deployment/CreateXScript.sol";

import {NATIVE_COIN, TEN_PERCENT} from "../src/constants/CArrakis.sol";
import {IOracleWrapper} from "../src/interfaces/IOracleWrapper.sol";
import {IAerodromeStandardModulePrivate} from
    "../src/interfaces/IAerodromeStandardModulePrivate.sol";
import {IArrakisMetaVaultFactory} from
    "../src/interfaces/IArrakisMetaVaultFactory.sol";

// IMPORTANT !!! Fill in / check these sensitive varaibles before running script !!!

address constant token0 = 0x4200000000000000000000000000000000000006;
address constant token1 = 0x9a33406165f562E16C3abD82fd1185482E01b49a;
int24 constant tickSpacing = 200;

bytes32 constant salt =
    keccak256(abi.encode("Mainnet WETH/TALENT Aerodrome private vault v1"));
address constant vaultOwner =
    0x81a1e7F34b9bABf172087cF5df8A4DF6500e9d4d;
uint256 constant init0 = 1;
uint256 constant init1 = 1;
uint24 constant maxSlippage = TEN_PERCENT / 2;

uint24 constant maxDeviation = TEN_PERCENT;
uint256 constant cooldownPeriod = 60;
address constant executor = 0xe012b59a8fC2D18e2C8943106a05C2702640440B;
address constant stratAnnouncer =
    0x81a1e7F34b9bABf172087cF5df8A4DF6500e9d4d;

address constant upgreadableBeacon = 0x8Dd906EcF9D434A3fBf2d60a14Fbf73d14d4Ea6e;

address constant factory = 0x820FB8127a689327C863de8433278d6181123982;
address constant oracle = 0xa552DfC7c9242A8F63a120901AAec76aC2473398;
address constant pool = 0x346eDb1aAa704dF6dDbfc604724AAFcdC12b2fed;
address constant aeroReceiver = 0x25CF23B54e25daaE3fe9989a74050b953A343823;

contract DeployAeroPrivateVault is CreateXScript {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        console.log("Deployer : ");
        console.logAddress(msg.sender);

        // #region create uni V4 oracle.

        // #region create private vault.

        bytes memory moduleCreationPayload = abi.encodeWithSelector(
            IAerodromeStandardModulePrivate.initialize.selector,
            IOracleWrapper(oracle),
            maxSlippage,
            aeroReceiver,
            tickSpacing
        );
        bytes memory initManagementPayload = abi.encode(
            IOracleWrapper(oracle),
            maxDeviation,
            cooldownPeriod,
            executor,
            stratAnnouncer,
            maxSlippage
        );

        address vault = IArrakisMetaVaultFactory(factory)
            .deployPrivateVault(
            salt,
            token0,
            token1,
            vaultOwner,
            upgreadableBeacon,
            moduleCreationPayload,
            initManagementPayload
        );

        console.logString("Aerodrome Private Vault Address : ");
        console.logAddress(vault);

        // #endregion create private vault.

        vm.stopBroadcast();
    }
}