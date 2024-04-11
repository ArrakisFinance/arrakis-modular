// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {ArrakisMetaVaultFactory} from
    "../src/ArrakisMetaVaultFactory.sol";
import {IValantisSOTModule} from
    "../src/interfaces/IValantisSOTModule.sol";
import {IOracleWrapper} from "../src/interfaces/IOracleWrapper.sol";
import {PIPS} from "../src/constants/CArrakis.sol";

/// @dev before this script we should whitelist the deployer as public vault deployer using the multisig
/// on the factory side.

bytes32 constant salt = keccak256(abi.encode("Salt 7"));
address constant token0 = 0x6A023CCd1ff6F2045C3309768eAd9E68F978f6e1;
address constant token1 = 0xDDAfbb505ad214D7b80b1f830fcCc89B60fb7A83;
address constant vaultOwner =
    0x81a1e7F34b9bABf172087cF5df8A4DF6500e9d4d;

address constant pool = 0xc878036B38Eb491D2C058F4030c2E10eA8f6A326;
uint256 constant init0 = 1e18;
uint256 constant init1 = 3200e6;
uint24 constant maxSlippage = PIPS / 50;
address constant oracle = 0x81a1e7F34b9bABf172087cF5df8A4DF6500e9d4d;

uint24 constant maxDeviation = PIPS / 50;
uint256 constant cooldownPeriod = 60;
address constant executor = 0x81a1e7F34b9bABf172087cF5df8A4DF6500e9d4d;
address constant stratAnnouncer =
    0x81a1e7F34b9bABf172087cF5df8A4DF6500e9d4d;

address constant valantisUpgradeableBeacon =
    0x736178Ca2bcAab06A19310a54a67c7B023499b87;
address constant factory = 0xe19Ae7e26993BB13D17A2aD7074Ad31bC2Ce72BA;

contract ValantisVaultOne is Script {
    function setUp() public {}

    function run() public {
        uint256 privateKey = vm.envUint("PK_TEST");

        address account = vm.addr(privateKey);

        console.logString("Deployer : ");
        console.logAddress(account);

        vm.startBroadcast(privateKey);

        bytes memory moduleCreationPayload = abi.encodeWithSelector(
            IValantisSOTModule.initialize.selector,
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
