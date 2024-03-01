// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {IArrakisMetaVault} from
    "../src/interfaces/IArrakisMetaVault.sol";
import {IValantisSOTModule} from
    "../src/interfaces/IValantisSOTModule.sol";
import {TimeLock} from "../src/TimeLock.sol";

/// @dev ask to valantis team to grant module as poolManager (sovereignPool) and
/// liquidityProvider (sot alm) before running this script.

address constant vault = 0x376e46d54AabfEd100aD1F4E252fe801bFdeC092;
address constant timeLock = 0x6843F708F3a7c624b4d1c806Af9003Fc31b90438;
address constant alm = 0xf678F3DF67EBea04b3a0c1C2636eEc2504c92BA2;
address constant vaultWeth =
    0x376e46d54AabfEd100aD1F4E252fe801bFdeC092;
address constant timeLockWeth =
    0x6866f6408Ac4471695A8575Da99BA8E01C043Cae;
address constant almWeth = 0xf678F3DF67EBea04b3a0c1C2636eEc2504c92BA2;

contract ValantisVaultTwo is Script {
    function setUp() public {}

    function run() public {
        uint256 privateKey = vm.envUint("PK_TEST");

        address account = vm.addr(privateKey);
        vm.startPrank(0x9403de4457C3a28F3CA8190bfbb4e1B1Cc88D978);

        console.log(account);

        // vm.startBroadcast(privateKey);

        address module = address(IArrakisMetaVault(vault).module());

        bytes memory data = abi.encodeWithSelector(
            IValantisSOTModule.setALMAndManagerFees.selector, alm
        );

        TimeLock(payable(timeLock)).schedule(
            module, 0, data, bytes32(0), bytes32(0), 1 minutes
        );

        module = address(IArrakisMetaVault(vaultWeth).module());

        data = abi.encodeWithSelector(
            IValantisSOTModule.setALMAndManagerFees.selector, almWeth
        );

        TimeLock(payable(timeLockWeth)).schedule(
            module, 0, data, bytes32(0), bytes32(0), 1 minutes
        );

        console.logString("Valantis Public Vault is initialized");
        console.logAddress(vault);

        vm.stopPrank();

        // vm.stopBroadcast();
    }
}
