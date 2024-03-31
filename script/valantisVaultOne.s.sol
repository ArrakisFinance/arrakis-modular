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

bytes32 constant salt = keccak256(abi.encode("Salt 5"));
address constant token0 = 0x64efc365149C78C55bfccaB24A48Ae03AffCa572;
address constant token1 = 0x682d49D0Ead2B178DE4125781d2CEd108bEe41fD;
address constant vaultOwner =
    0x81a1e7F34b9bABf172087cF5df8A4DF6500e9d4d;

address constant pool = 0x46046EaA48097729604CbA5603E440E4021b61D7;
uint256 constant init0 = 3200e6;
uint256 constant init1 = 1e18;
uint24 constant maxSlippage = PIPS / 50;
address constant oracle = 0x81a1e7F34b9bABf172087cF5df8A4DF6500e9d4d;

uint24 constant maxDeviation = PIPS / 50;
uint256 constant cooldownPeriod = 60;
address constant executor = 0x81a1e7F34b9bABf172087cF5df8A4DF6500e9d4d;
address constant stratAnnouncer =
    0x81a1e7F34b9bABf172087cF5df8A4DF6500e9d4d;

address constant valantisUpgradeableBeacon =
    0xF5488214f5dEb15D0964a2593d7e94a4D74e1151;
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
