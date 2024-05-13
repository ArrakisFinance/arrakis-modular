// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {IValantisHOTModule} from
    "../src/interfaces/IValantisHOTModule.sol";
import {IArrakisStandardManager} from
    "../src/interfaces/IArrakisStandardManager.sol";

// For Gnosis chain.

address constant vault = address(0);
address constant manager = address(0);
uint160 constant sqrtPriceLowX96 = 0;
uint160 constant sqrtPriceHighX96 = 0;
uint160 constant expectedSqrtSpotPriceLowerX96 = 0;
uint160 constant expectedSqrtSpotPriceUpperX96 = 0;

contract RebalancePriceBound is Script {
    function setUp() public {}

    function run() public {
        uint256 privateKey = vm.envUint("PK_TEST");

        address account = vm.addr(privateKey);

        console.log(account);

        vm.startBroadcast(privateKey);

        bytes memory payload = abi.encodeWithSelector(
            IValantisHOTModule.setPriceBounds.selector,
            sqrtPriceLowX96,
            sqrtPriceHighX96,
            expectedSqrtSpotPriceLowerX96,
            expectedSqrtSpotPriceUpperX96
        );

        bytes[] memory payloads = new bytes[](1);
        payloads[0] = payload;

        IArrakisStandardManager(manager).rebalance(vault, payloads);

        console.logString("Set Price Bounds in vault : ");
        console.logAddress(vault);

        vm.stopBroadcast();
    }
}
