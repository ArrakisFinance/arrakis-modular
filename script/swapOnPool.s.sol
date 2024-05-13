// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {IArrakisMetaVault} from
    "../src/interfaces/IArrakisMetaVault.sol";
import {IArrakisMetaVaultPublic} from
    "../src/interfaces/IArrakisMetaVaultPublic.sol";
import {TimeLock} from "../src/TimeLock.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// #region valantis contracts.
import {ISovereignPool} from
    "../lib/valantis-hot/lib/valantis-core/src/pools/interfaces/ISovereignPool.sol";
import {
    SovereignPoolSwapParams,
    SovereignPoolSwapContextData
} from
    "../lib/valantis-hot/lib/valantis-core/src/pools/structs/SovereignPoolStructs.sol";
// #endregion valantis contracts.

// For Gnosis chain.

address constant pool = 0x46046EaA48097729604CbA5603E440E4021b61D7;
address constant tokenIn = 0x64efc365149C78C55bfccaB24A48Ae03AffCa572;
address constant tokenOut = 0x682d49D0Ead2B178DE4125781d2CEd108bEe41fD;
bool constant isSwapCallback = false; // not needed as we are swapping through an EOA.
bool constant isZeroForOne = true;
uint256 constant amountIn = 50e6; // to set.
uint256 constant amountOutMin = 0.009e18; // to set.
address constant recipient =
    0x81a1e7F34b9bABf172087cF5df8A4DF6500e9d4d;

contract SwapOnPool is Script {
    function setUp() public {}

    function run() public {
        uint256 privateKey = vm.envUint("PK_TEST");

        address account = vm.addr(privateKey);

        console.log(account);

        vm.startBroadcast(privateKey);

        ERC20(tokenIn).approve(pool, amountIn);

        SovereignPoolSwapContextData memory data;
        SovereignPoolSwapParams memory params =
        SovereignPoolSwapParams({
            isSwapCallback: isSwapCallback,
            isZeroToOne: isZeroForOne,
            amountIn: amountIn,
            amountOutMin: amountOutMin,
            recipient: recipient,
            deadline: block.timestamp + 3600,
            swapTokenOut: tokenOut,
            swapContext: data
        });

        ISovereignPool(pool).swap(params);

        console.logString("Normal swap on :");
        console.logAddress(pool);

        vm.stopBroadcast();
    }
}
