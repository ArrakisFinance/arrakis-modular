// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {IArrakisMetaVault} from
    "../src/interfaces/IArrakisMetaVault.sol";
import {IOracleWrapper} from "../src/interfaces/IOracleWrapper.sol";
import {SetupParams} from "../src/structs/SManager.sol";
import {ArrakisStandardManager} from
    "../src/ArrakisStandardManager.sol";
import {TimeLock} from "../src/TimeLock.sol";
import {PIPS} from "../src/constants/CArrakis.sol";

// For Gnosis chain.

address constant vault = 0x2A1EB0bc234F283a6de7150464b3c30049F97545;
address payable constant manager =
    payable(0x2e6E879648293e939aA68bA4c6c129A1Be733bDA);

contract UpdateVaultInfo is Script {
    function setUp() public {}

    function run() public {

        console.log(msg.sender);

        vm.startBroadcast();

        (
            ,
            uint256 cooldownPeriod,
            IOracleWrapper oracle,
            uint24 maxDeviation,
            address executor,
            address stratAnnouncer,
            uint24 maxSlippagePIPS,
        ) = ArrakisStandardManager(manager).vaultInfo(vault);

        SetupParams memory params = SetupParams({
            vault: vault,
            oracle: oracle,
            maxDeviation: PIPS,
            cooldownPeriod: cooldownPeriod,
            executor: executor,
            stratAnnouncer: stratAnnouncer,
            maxSlippagePIPS: maxSlippagePIPS
        });

        ArrakisStandardManager(manager).updateVaultInfo(params);

        console.logString(
            "Valantis Public Vault executor update scheduled"
        );
        console.logAddress(vault);

        vm.stopBroadcast();
    }
}
