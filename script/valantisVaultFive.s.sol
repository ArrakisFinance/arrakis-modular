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

address constant vault = 0x2b15756E32Af0B47FB1d44DB1F7b71FeB457c5E7;
address payable constant manager =
    payable(0x9E09D9943B40685e8B78f6DC43069652dd6E6efD);
address constant timeLock = 0xb527cb6AD6A92041fA7bAFe41798F8c46f070a20;
address constant sotOracleWrapper =
    0x781a349e66Cf9E909af1EcDEFb75Fc3B87e54D3a;

contract ValantisVaultFive is Script {
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

        TimeLock(payable(timeLock)).execute(
            manager, 0, data, bytes32(0), bytes32(0)
        );

        console.logString("Valantis Public Vault oracle updated");
        console.logAddress(vault);

        vm.stopBroadcast();
    }
}
