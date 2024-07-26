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
import {AddLiquidityData} from "../src/structs/SRouter.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// IMPORTANT !!! Fill in / check these sensitive varaibles before running script !!!

address constant vault = 0x1fbdAfE1131A29E8AFe04CC6BCBEA449235574b3; // arbitrum eth/usdc
address constant router = 0xd3Db920D1403a5438A50d73f375b0DFf5a6Df9fC;
uint256 constant maxAmount0 = 0.1 ether;
uint256 constant maxAmount1 = 0.1*(10**6);
// !! your address below !!
address constant receiver = 0x9403de4457C3a28F3CA8190bfbb4e1B1Cc88D978;

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
        //address module = address(IArrakisMetaVault(vault).module());

        ERC20(token0).approve(router, maxAmount0);
        ERC20(token1).approve(router, maxAmount1);

        (amount0, amount1, shares) = IArrakisPublicVaultRouter(router).addLiquidity(
            AddLiquidityData({
                amount0Max: maxAmount0,
                amount1Max: maxAmount1,
                amount0Min: amount0*99/100,
                amount1Min: amount1*99/100,
                amountSharesMin: shares*99/100,
                vault: vault,
                receiver: receiver
            })
        );

        console.logString("Valantis Public Vault mint via Router");
        console.logAddress(vault);

        console.logUint(amount0);
        console.logUint(amount1);
        console.logUint(shares);

        vm.stopBroadcast();
    }
}