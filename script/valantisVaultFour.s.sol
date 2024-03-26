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

address constant vault = 0x89Ea626ECAC279a535ec7bA6ab1Fe0ab6a4eB440;
address payable constant manager =
    payable(0x9E09D9943B40685e8B78f6DC43069652dd6E6efD);
address constant timeLock = 0xD41479D3f6c42cF6F532DF0F64Ca132342661f07;
address constant sotOracleWrapper =
    0x4409d89Ab5332B6FB71b5d74d3eE94171A889041;

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
            address executor,
            address stratAnnouncer,
            uint24 maxSlippagePIPS,
        ) = ArrakisStandardManager(manager).vaultInfo(vault);

        SetupParams memory params = SetupParams({
            vault: vault,
            oracle: IOracleWrapper(sotOracleWrapper),
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
            manager, 0, data, bytes32(0), bytes32(0), 1 minutes
        );

        console.logString("Valantis Public Vault oracle update scheduled");
        console.logAddress(vault);

        vm.stopBroadcast();
    }
}
