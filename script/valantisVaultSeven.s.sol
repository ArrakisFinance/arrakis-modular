// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

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

address constant vault = 0x55C21FD657ebBD4D91b2051d9e327D8fdE9c415D;
address payable constant manager =
    payable(0x9E09D9943B40685e8B78f6DC43069652dd6E6efD);
address constant timeLock = 0x6Db15200e553bc0Ca146ebD7838502e5d33255cf;
address constant executor =
    0xacf11AFFD3ED865FA2Df304eC5048C29597F38F9;

contract ValantisVaultSeven is Script {
    function setUp() public {}

    function run() public {
        uint256 privateKey = vm.envUint("PK_TEST");

        address account = vm.addr(privateKey);

        console.log(account);

        vm.startBroadcast(privateKey);

        (
            ,
            uint256 cooldownPeriod,
            IOracleWrapper oracle,
            uint24 maxDeviation,
            ,
            address stratAnnouncer,
            uint24 maxSlippagePIPS,
        ) = ArrakisStandardManager(manager).vaultInfo(vault);

        SetupParams memory params = SetupParams({
            vault: vault,
            oracle: oracle,
            maxDeviation: maxDeviation,
            cooldownPeriod: cooldownPeriod,
            executor: executor,
            stratAnnouncer: stratAnnouncer,
            maxSlippagePIPS: maxSlippagePIPS
        });

        bytes memory data = abi.encodeWithSelector(
            ArrakisStandardManager.updateVaultInfo.selector, params
        );

        TimeLock(payable(timeLock)).execute(
            manager, 0, data, bytes32(0), bytes32(0)
        );

        console.logString("Valantis Public Vault oracle updated");
        console.logAddress(vault);

        vm.stopBroadcast();
    }
}
