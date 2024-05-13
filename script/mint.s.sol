// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {IArrakisMetaVault} from
    "../src/interfaces/IArrakisMetaVault.sol";
import {IArrakisMetaVaultPublic} from
    "../src/interfaces/IArrakisMetaVaultPublic.sol";
import {IArrakisPublicVaultRouter} from
    "../src/interfaces/IArrakisPublicVaultRouter.sol";
import {TimeLock} from "../src/TimeLock.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// For Gnosis chain.

address constant vault = 0x8cE9786dc4bbB558C1F219f10b1F2f70A6Ced7eC;
address constant router = 0x0210771fE1D7aDC2a4F747e3553A5710132d2b36;
uint256 constant maxAmount1 = 490_000;
uint256 constant maxAmount0 = 160_000_000_000_000;
address constant receiver = 0x81a1e7F34b9bABf172087cF5df8A4DF6500e9d4d;

contract Mint is Script {
    function setUp() public {}

    function run() public {
        uint256 privateKey = vm.envUint("PK_TEST");

        address account = vm.addr(privateKey);

        console.log(account);

        vm.startBroadcast(privateKey);

        (uint256 shares, uint256 amount0, uint256 amount1) =
        IArrakisPublicVaultRouter(router).getMintAmounts(
            vault, maxAmount0, maxAmount1
        );

        address token0 = IArrakisMetaVault(vault).token0();
        address token1 = IArrakisMetaVault(vault).token1();
        address module = address(IArrakisMetaVault(vault).module());

        ERC20(token0).approve(module, amount0);
        ERC20(token1).approve(module, amount1);

        IArrakisMetaVaultPublic(vault).mint(shares, receiver);

        console.logString("Valantis Public Vault mint");
        console.logAddress(vault);

        console.logUint(amount0);
        console.logUint(amount1);
        console.logUint(shares);

        vm.stopBroadcast();
    }
}
