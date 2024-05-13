// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {IArrakisMetaVault} from
    "../src/interfaces/IArrakisMetaVault.sol";
import {IValantisHOTModule} from
    "../src/interfaces/IValantisHOTModule.sol";
import {IArrakisStandardManager} from
    "../src/interfaces/IArrakisStandardManager.sol";

import {Dex} from "../test/tests/Dex.sol";

address constant vault = address(0);
bool constant isZeroForOne = true;
uint256 constant amountIn = 50e6; // to set.
uint256 constant amountOutMin = 0.009e18; // to set.
address constant router = address(0); // Dex test contract address.
address constant manager = address(0);

contract SwapOnPool is Script {
    function setUp() public {}

    function run() public {
        uint256 privateKey = vm.envUint("PK_TEST");

        address account = vm.addr(privateKey);

        console.log(account);

        vm.startBroadcast(privateKey);

        (uint256 amount0, uint256 amount1) =
            IArrakisMetaVault(vault).totalUnderlying();

        if (isZeroForOne) {
            if (amountIn > amount0) revert("Not enough token0");
            amount0 = amountIn;
            amount1 = amountOutMin;
        } else {
            if (amountIn > amount1) revert("Not enough token1");
            amount1 = amountIn;
            amount0 = amountOutMin;
        }

        bytes memory p = abi.encodeWithSelector(
            Dex.swap.selector, isZeroForOne, amount0, amount1
        );

        bytes memory payload = abi.encodeWithSelector(
            IValantisHOTModule.swap.selector,
            isZeroForOne,
            amountOutMin,
            amountIn,
            router,
            0,
            0,
            p
        );

        bytes[] memory payloads = new bytes[](1);

        payloads[0] = payload;

        IArrakisStandardManager(manager).rebalance(vault, payloads);

        console.logString("Rebalance inventory of vault : ");
        console.logAddress(vault);

        vm.stopBroadcast();
    }
}
