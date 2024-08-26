// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {IArrakisMetaVault} from
    "../src/interfaces/IArrakisMetaVault.sol";
import {HOTOracleWrapper} from "../src/modules/HOTOracleWrapper.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @dev ask to valantis team to grant module as poolManager (sovereignPool) and
/// liquidityProvider (hot alm) before running this script.

address constant vault = 0xf790870ccF6aE66DdC69f68e6d05d446f1a6ad83;
address constant alm = 0x3269994964DFE4aa5f8dd0C99eD40e881562132A;

// arbitrum HOT Oracle Wrapper: 0xE4DB6eA3a076aD4Cb1795c6517DA4bb60FD507f0. (WETH/USDC) for alm 0xC4c855095f5872BeC67d0916D49cf881d4fafe1e and vault 0xf790870ccF6aE66DdC69f68e6d05d446f1a6ad83.
// mainnet HOT Oracle Wrapper : 0xF23d83Da92844C53aD57e6031c231dC93eC4eE80. (WETH/USDC) for alm 0x3269994964DFE4aa5f8dd0C99eD40e881562132A and vault 0xf790870ccF6aE66DdC69f68e6d05d446f1a6ad83.
contract HOTOracle is Script {
    function setUp() public {}

    function run() public {
        uint256 privateKey = vm.envUint("PK_TEST");

        address account = vm.addr(privateKey);

        console.log(account);

        vm.startBroadcast(privateKey);

        address token0 = IArrakisMetaVault(vault).token0();
        address token1 = IArrakisMetaVault(vault).token1();

        uint8 decimals0 = ERC20(token0).decimals();
        uint8 decimals1 = ERC20(token1).decimals();

        address oracleWrapper =
            address(new HOTOracleWrapper(alm, decimals0, decimals1));

        console.logString("HOT Oracle wrapper Address : ");
        console.logAddress(oracleWrapper);

        vm.stopPrank();

        // vm.stopBroadcast();
    }
}
