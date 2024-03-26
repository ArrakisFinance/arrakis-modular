// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {IArrakisMetaVault} from
    "../src/interfaces/IArrakisMetaVault.sol";
import {IArrakisMetaVaultPublic} from
    "../src/interfaces/IArrakisMetaVaultPublic.sol";
import {TimeLock} from "../src/TimeLock.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// For Gnosis chain.

address constant vault = 0x89Ea626ECAC279a535ec7bA6ab1Fe0ab6a4eB440;
uint256 constant shares = 1e18;
uint256 constant amount0 = 3200e6;
uint256 constant amount1 = 1e18;
address constant receiver = 0x81a1e7F34b9bABf172087cF5df8A4DF6500e9d4d;

contract Mint is Script {
    function setUp() public {}

    function run() public {
        uint256 privateKey = vm.envUint("PK_TEST");

        address account = vm.addr(privateKey);

        console.log(account);

        vm.startBroadcast(privateKey);

        address token0 = IArrakisMetaVault(vault).token0();
        address token1 = IArrakisMetaVault(vault).token1();
        address module = address(IArrakisMetaVault(vault).module());

        ERC20(token0).approve(module, amount0);
        ERC20(token1).approve(module, amount1);

        IArrakisMetaVaultPublic(vault).mint(shares, receiver);

        console.logString("Valantis Public Vault mint");
        console.logAddress(vault);

        vm.stopBroadcast();
    }
}
