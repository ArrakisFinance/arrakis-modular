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

bytes32 constant salt = keccak256(abi.encode("Salt 2"));
address constant token0 = 0x4F5e836680b9aac98dFA2af775D29Bdd8C68cB91;
address constant token1 = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9;
address constant vaultOwner = 0x9403de4457C3a28F3CA8190bfbb4e1B1Cc88D978;

address constant pool = 0x8Cb689ABDB29381A9ABeE33889601d90D528A47a;
uint256 constant init0 = 2000e6;
uint256 constant init1 = 1e18;
uint24 constant maxSlippage = PIPS/50;
address constant oracle = 0x9403de4457C3a28F3CA8190bfbb4e1B1Cc88D978;

uint24 constant maxDeviation = PIPS/50;
uint256 constant cooldownPeriod = 60;
address constant executor = 0x9403de4457C3a28F3CA8190bfbb4e1B1Cc88D978;
address constant stratAnnouncer = 0x9403de4457C3a28F3CA8190bfbb4e1B1Cc88D978;

address constant valantisUpgradeableBeacon = 0xF4A0D83a7114e435cFB2D2E248d633b4C9cC8ED5;
address constant factory = 0x10ca44D32e6d01E24cD33162634284e39BA4C471;

contract ValantisVaultOne is Script {
    function setUp() public {}

    function run() public {
        uint256 privateKey = vm.envUint("PK_TEST");

        address account = vm.addr(privateKey);

        vm.startBroadcast(privateKey);

        bytes memory moduleCreationPayload = abi.encodeWithSelector(
            IValantisSOTModule.initialize.selector,
            pool,
            init0,
            init1,
            maxSlippage,
            oracle
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
