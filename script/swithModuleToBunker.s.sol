// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

// #region foundry.

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

// #endregion foundry.

import {ArrakisRoles} from "./deployment/constants/ArrakisRoles.sol";

// #region modular.

import {IValantisHOTModule} from
    "../src/interfaces/IValantisHOTModule.sol";
import {
    IArrakisStandardManager,
    SetupParams
} from "../src/interfaces/IArrakisStandardManager.sol";
import {VaultInfo} from "../src/structs/SManager.sol";
import {TimeLock} from "../src/TimeLock.sol";

// #endregion modular.

address constant vault = 0xf790870ccF6aE66DdC69f68e6d05d446f1a6ad83;
// Valantis module address.
address constant module = 0x505f0Cc4D88E1B32d3F0F7FBf21258d2B30aD1E5;
// Bunker module address.
address constant bunker = 0xB48dc9299b1f98b14dee0a4451f3b7FFf32285F1; // arbitrum 0x713D26489aa8205d272008A3ea5df93d86c4e58f
address constant manager = 0x2e6E879648293e939aA68bA4c6c129A1Be733bDA;

address constant vaultOwner =
    0xCFaD8B6981Da1c734352Bd31618040C23FE99117;

contract SwithModuleToBunker is Script {
    function setUp() public {}

    function run() public {
        // vm.startBroadcast();

        console.log("Deployer :");
        console.logAddress(msg.sender);

        address newExecutor = ArrakisRoles.getOwner();

        // #region change executor.

        VaultInfo memory vaultInfo;
        (
            ,
            vaultInfo.cooldownPeriod,
            vaultInfo.oracle,
            vaultInfo.maxDeviation,
            vaultInfo.executor,
            vaultInfo.stratAnnouncer,
            vaultInfo.maxSlippagePIPS,
        ) = IArrakisStandardManager(manager).vaultInfo(vault);

        bytes memory payload = abi.encodeWithSelector(
            IArrakisStandardManager.updateVaultInfo.selector,
            SetupParams({
                vault: vault,
                oracle: vaultInfo.oracle,
                maxDeviation: vaultInfo.maxDeviation,
                cooldownPeriod: vaultInfo.cooldownPeriod,
                executor: newExecutor,
                stratAnnouncer: vaultInfo.stratAnnouncer,
                maxSlippagePIPS: vaultInfo.maxSlippagePIPS
            })
        );

        console.log("Payload to change executor : ");
        console.logBytes(payload);

        vm.startPrank(newExecutor);

        TimeLock(payable(vaultOwner)).schedule(
            manager, 0, payload, "", "", 2 days
        );

        vm.stopPrank();

        // vm.startPrank(vaultOwner);

        // IArrakisStandardManager(manager).updateVaultInfo(SetupParams({
        //         vault: vault,
        //         oracle: vaultInfo.oracle,
        //         maxDeviation: vaultInfo.maxDeviation,
        //         cooldownPeriod: vaultInfo.cooldownPeriod,
        //         executor: newExecutor,
        //         stratAnnouncer: vaultInfo.stratAnnouncer,
        //         maxSlippagePIPS: vaultInfo.maxSlippagePIPS
        //     }));

        // vm.stopPrank();

        // #endregion change executor.

        // #region create payload to change module.

        // #endregion create payload to change module.

        // vm.stopBroadcast();
    }
}
