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

address constant vault = 0x8cE9786dc4bbB558C1F219f10b1F2f70A6Ced7eC;
address payable constant manager =
    payable(0xb6F7f65a5cc81B5dA5E9aB58FB37Cb174f4Fb3ca);
address constant timeLock = 0x119e26B6D72376Ac741d5546eA295d1A0160E26c;
address constant executor = 0xacf11AFFD3ED865FA2Df304eC5048C29597F38F9;

contract ValantisVaultSeven is Script {
    function setUp() public {}

    function run() public {

        console.log(msg.sender);

        vm.startBroadcast();

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
