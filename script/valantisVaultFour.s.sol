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

// For Gnosis chain.

address constant vault = 0xf790870ccF6aE66DdC69f68e6d05d446f1a6ad83;
address payable constant manager =
    payable(0x2e6E879648293e939aA68bA4c6c129A1Be733bDA);
address constant timeLock = 0xCFaD8B6981Da1c734352Bd31618040C23FE99117;
address constant hotOracleWrapper =
    0xF23d83Da92844C53aD57e6031c231dC93eC4eE80;
address constant executor = 0xacf11AFFD3ED865FA2Df304eC5048C29597F38F9;

contract ValantisVaultFour is Script {
    function setUp() public {}

    function run() public {
        uint256 privateKey = vm.envUint("PK_TEST");

        address account = vm.addr(privateKey);

        console.log(account);

        vm.startBroadcast(privateKey);

        (
            ,
            uint256 cooldownPeriod,
            ,
            uint24 maxDeviation,
            ,
            address stratAnnouncer,
            uint24 maxSlippagePIPS,
        ) = ArrakisStandardManager(manager).vaultInfo(vault);

        SetupParams memory params = SetupParams({
            vault: vault,
            oracle: IOracleWrapper(hotOracleWrapper),
            maxDeviation: maxDeviation,
            cooldownPeriod: cooldownPeriod,
            executor: executor,
            stratAnnouncer: stratAnnouncer,
            maxSlippagePIPS: maxSlippagePIPS
        });

        bytes memory data = abi.encodeWithSelector(
            ArrakisStandardManager.updateVaultInfo.selector, params
        );

        TimeLock(payable(timeLock)).schedule(
            manager, 0, data, bytes32(0), bytes32(0), 2 days
        );

        console.logString(
            "Valantis Public Vault oracle update scheduled"
        );
        console.logAddress(vault);

        vm.stopBroadcast();
    }
}
