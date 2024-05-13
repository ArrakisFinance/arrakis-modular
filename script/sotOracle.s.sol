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

address constant vault = 0x8cE9786dc4bbB558C1F219f10b1F2f70A6Ced7eC;
address constant alm = 0x614b8B047cAfEc2Fcfc788dd4aFE9e32fe924Cd0;

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
