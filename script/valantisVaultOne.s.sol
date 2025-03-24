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
    keccak256(abi.encode("Salt WBTC/USDC vault"));
address constant token0 = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
address constant token1 = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
address constant vaultOwner =
    0x81a1e7F34b9bABf172087cF5df8A4DF6500e9d4d;

address constant pool = 0x0Fc814C9978350d86E03ad3a5BcFc74b02599b13;
uint256 constant init0 = 1e8;
uint256 constant init1 = 61000e6;
uint24 constant maxSlippage = PIPS / 50;
address constant oracle = 0x81a1e7F34b9bABf172087cF5df8A4DF6500e9d4d;

uint24 constant maxDeviation = PIPS / 50;
uint256 constant cooldownPeriod = 60;
address constant executor = 0x81a1e7F34b9bABf172087cF5df8A4DF6500e9d4d;
address constant stratAnnouncer =
    0x81a1e7F34b9bABf172087cF5df8A4DF6500e9d4d;

address constant valantisUpgradeableBeacon =
    0xE973Cf1e347EcF26232A95dBCc862AA488b0351b;
address constant factory = 0x820FB8127a689327C863de8433278d6181123982;

// Salt for WETH/USDC : "Salt WETH/USDC USDC/WETH vault"
// Arbitrum TimeLock Address WETH/USDC : 0xCFaD8B6981Da1c734352Bd31618040C23FE99117.
// Arbitrum ArrakisMetaVaultPublic WETH/USDC : 0xf790870ccF6aE66DdC69f68e6d05d446f1a6ad83.
// Arbitrum Valantis Module WETH/USDC : 0x06aAd5A57722336C3b04C6515BBC1f83212f5D4a.

// Mainnet TimeLock Address WETH/USDC : 0xCFaD8B6981Da1c734352Bd31618040C23FE99117.
// Mainnet ArrakisMetaVaultPublic WETH/USDC : 0xf790870ccF6aE66DdC69f68e6d05d446f1a6ad83.
// Mainnet Valantis Module WETH/USDC : 0x505f0Cc4D88E1B32d3F0F7FBf21258d2B30aD1E5.

// Base TimeLock Address WETH/USDC : 0xCFaD8B6981Da1c734352Bd31618040C23FE99117.
// Base ArrakisMetaVaultPublic WETH/USDC : 0xf790870ccF6aE66DdC69f68e6d05d446f1a6ad83.
// Base Valantis Module WETH/USDC : 0xE78311B9e0bBE4EB295AaF298A06e3dDcD3f226B.

// Mainnet TimeLock Address WBTC/USDC : 0xf4f5BFF5837678B59427C5e992cdaFc6a4070A1B.
// Mainnet ArrakisMetaVaultPublic WBTC/USDC : 0xAdB8a6A0279F50c54cd1a3b5C6BBfCC2094D6338.
// Mainnet Valantis Module WBTC/USDC : 0xAf1E9f7A08A23c4c22E84881A5Dc0236c801C3FD.
contract ValantisVaultOne is Script {
    function setUp() public {}

    function run() public {

        console.logString("Deployer : ");
        console.logAddress(msg.sender);

        vm.startBroadcast();

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
