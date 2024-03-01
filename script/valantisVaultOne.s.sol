// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {ArrakisMetaVaultFactory} from
    "../src/ArrakisMetaVaultFactory.sol";
import {IValantisSOTModule} from
    "../src/interfaces/IValantisSOTModule.sol";
import {IOracleWrapper} from "../src/interfaces/IOracleWrapper.sol";

/// @dev before this script we should whitelist the deployer as public vault deployer using the multisig
/// on the factory side.

bytes32 constant salt = bytes32(0);
address constant token0 = address(0);
address constant token1 = address(0);
address constant vaultOwner = address(0);

address constant pool = address(0);
uint256 constant init0 = 0;
uint256 constant init1 = 0;
uint24 constant maxSlippage = 0;
address constant oracle = address(0);

uint24 constant maxDeviation = 0;
uint256 constant cooldownPeriod = 0;
address constant executor = address(0);
address constant stratAnnouncer = address(0);

address constant valantisUpgradeableBeacon = address(0);
address constant factory = address(0);

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
