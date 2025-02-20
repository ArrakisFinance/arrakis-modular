// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {IArrakisMetaVault} from
    "../src/interfaces/IArrakisMetaVault.sol";
import {IValantisHOTModule} from
    "../src/interfaces/IValantisHOTModule.sol";
import {SetupParams} from "../src/structs/SManager.sol";
import {ArrakisStandardManager} from
    "../src/ArrakisStandardManager.sol";
import {IOracleWrapper} from "../src/interfaces/IOracleWrapper.sol";

// For Gnosis chain.

address constant vault = 0x4bBFca3EaAC2cDa8c308CEB532a7792B54c8d781;
// address constant alm = 0xE96fED9054F5DEa8Af4c9E924319a02d5a2a8935;
// address constant oracle = 0x1DDDEc1cE817bc771b6339E9DE97ae81B3bE0da4;
address payable constant manager =
    payable(0x2e6E879648293e939aA68bA4c6c129A1Be733bDA);
address constant executor = 0xe012b59a8fC2D18e2C8943106a05C2702640440B;

contract ValantisVaultSetupPrivate is Script {
    function setUp() public {}

    function run() public {

        console.log(msg.sender);

        vm.startBroadcast();

        address module = address(IArrakisMetaVault(vault).module());

        // IValantisHOTModule(module).setALMAndManagerFees(alm, oracle);

        // #region manager vault info setup.

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

        // #endregion manager vault info setup.

        ArrakisStandardManager(manager).updateVaultInfo(params);

        console.logString("Valantis Private Vault is initialized");
        console.logAddress(vault);

        vm.stopBroadcast();
    }
}
