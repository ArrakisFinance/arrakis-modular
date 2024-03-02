// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {IArrakisMetaVault} from
    "../src/interfaces/IArrakisMetaVault.sol";
import {SOTOracleWrapper} from "../src/modules/SOTOracleWrapper.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @dev ask to valantis team to grant module as poolManager (sovereignPool) and
/// liquidityProvider (sot alm) before running this script.

address constant vault = 0x0F3dA211578795e950699Ab56704c6Def49D772c;
address constant alm = 0xffb666fE4C401Af7FbdE1C7b675f379dfF34997D;

contract SOTOracle is Script {
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
            address(new SOTOracleWrapper(alm, decimals0, decimals1));

        console.logString("SOT Oracle wrapper Address : ");
        console.logAddress(oracleWrapper);

        vm.stopPrank();

        // vm.stopBroadcast();
    }
}
