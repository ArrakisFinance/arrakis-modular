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

address constant vault = 0xf790870ccF6aE66DdC69f68e6d05d446f1a6ad83;
address constant router = 0x72aa2C8e6B14F30131081401Fa999fC964A66041;
uint256 constant maxAmount0 = 98_000_000_000_000_000;
uint256 constant maxAmount1 = 226_000_000;
// !! your address below !!
address constant receiver = 0x81a1e7F34b9bABf172087cF5df8A4DF6500e9d4d;

contract Mint is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        console.log(msg.sender);

        (uint256 shares, uint256 amount0, uint256 amount1) =
        IArrakisPublicVaultRouter(router).getMintAmounts(
            vault, maxAmount0, maxAmount1
        );

        address token0 = IArrakisMetaVault(vault).token0();
        address token1 = IArrakisMetaVault(vault).token1();

        ERC20(token0).approve(router, amount0);
        ERC20(token1).approve(router, amount1);

        IArrakisPublicVaultRouter(router).addLiquidity(
            AddLiquidityData({
                amount0Max: maxAmount0,
                amount1Max: maxAmount1,
                amount0Min: amount0,
                amount1Min: amount1,
                amountSharesMin: shares,
                vault: vault,
                receiver: receiver
            })
        );

        console.logString("Valantis Public Vault mint");
        console.logAddress(vault);

        console.logUint(amount0);
        console.logUint(amount1);
        console.logUint(shares);

        vm.stopBroadcast();
    }
}
