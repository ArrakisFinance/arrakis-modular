// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {ArrakisMetaVaultFactory} from
    "../src/ArrakisMetaVaultFactory.sol";
import {IValantisHOTModule} from
    "../src/interfaces/IValantisHOTModule.sol";
import {IOracleWrapper} from "../src/interfaces/IOracleWrapper.sol";
import {PIPS} from "../src/constants/CArrakis.sol";

/// @dev before this script we should whitelist the deployer as public vault deployer using the multisig
/// on the factory side.

bytes32 constant salt =
    keccak256(abi.encode("Salt WETH/USDC USDC/WETH vault"));
address constant token0 = 0x4200000000000000000000000000000000000006;
address constant token1 = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
address constant vaultOwner =
    0x81a1e7F34b9bABf172087cF5df8A4DF6500e9d4d;

address constant pool = 0x159DD549399811CD6247Fb457497414baF8BFb08;
uint256 constant init0 = 1e18;
uint256 constant init1 = 2520e6;
uint24 constant maxSlippage = PIPS / 50;
address constant oracle = 0x81a1e7F34b9bABf172087cF5df8A4DF6500e9d4d;

uint24 constant maxDeviation = PIPS / 50;
uint256 constant cooldownPeriod = 60;
address constant executor = 0x81a1e7F34b9bABf172087cF5df8A4DF6500e9d4d;
address constant stratAnnouncer =
    0x81a1e7F34b9bABf172087cF5df8A4DF6500e9d4d;

address constant valantisUpgradeableBeacon =
    0xCc8989978668ad377369C0cC720192377a6006e3;
address constant factory = 0x820FB8127a689327C863de8433278d6181123982;

// Arbitrum TimeLock Address WETH/USDC : 0xCFaD8B6981Da1c734352Bd31618040C23FE99117.
// Arbitrum ArrakisMetaVaultPublic WETH/USDC : 0xf790870ccF6aE66DdC69f68e6d05d446f1a6ad83.
// Arbitrum Valantis Module WETH/USDC : 0x06aAd5A57722336C3b04C6515BBC1f83212f5D4a.

// Mainnet TimeLock Address WETH/USDC : 0xCFaD8B6981Da1c734352Bd31618040C23FE99117.
// Mainnet ArrakisMetaVaultPublic WETH/USDC : 0xf790870ccF6aE66DdC69f68e6d05d446f1a6ad83.
// Mainnet Valantis Module WETH/USDC : 0x505f0Cc4D88E1B32d3F0F7FBf21258d2B30aD1E5.

// Base TimeLock Address WETH/USDC : 0xCFaD8B6981Da1c734352Bd31618040C23FE99117.
// Base ArrakisMetaVaultPublic WETH/USDC : 0xf790870ccF6aE66DdC69f68e6d05d446f1a6ad83.
// Base Valantis Module WETH/USDC : 0xE78311B9e0bBE4EB295AaF298A06e3dDcD3f226B.
contract ValantisVaultOne is Script {
    function setUp() public {}

    function run() public {
        uint256 privateKey = vm.envUint("PK_TEST");

        address account = vm.addr(privateKey);

        console.logString("Deployer : ");
        console.logAddress(account);

        vm.startBroadcast(privateKey);

        bytes memory moduleCreationPayload = abi.encodeWithSelector(
            IValantisHOTModule.initialize.selector,
            pool,
            init0,
            init1,
            maxSlippage
        );
        bytes memory initManagementPayload = abi.encode(
            IOracleWrapper(oracle),
            maxDeviation,
            cooldownPeriod,
            executor,
            stratAnnouncer,
            maxSlippage
        );

        address vault = ArrakisMetaVaultFactory(factory)
            .deployPublicVault(
            salt,
            token0,
            token1,
            vaultOwner,
            valantisUpgradeableBeacon,
            moduleCreationPayload,
            initManagementPayload
        );

        console.logString("Valantis Public Vault Address : ");
        console.logAddress(vault);

        vm.stopBroadcast();
    }
}
