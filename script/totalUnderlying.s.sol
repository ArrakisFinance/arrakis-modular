// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

// #region foundry.

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

// #endregion foundry.

// #region modular.

import {IArrakisLPModule} from "../src/interfaces/IArrakisLPModule.sol";
import {IArrakisMetaVault} from "../src/interfaces/IArrakisMetaVault.sol";
import {IArrakisMetaVaultPrivate} from "../src/interfaces/IArrakisMetaVaultPrivate.sol";
import {IPancakeSwapV4StandardModule} from "../src/interfaces/IPancakeSwapV4StandardModule.sol";

// #endregion modular.

import {PancakeUnderlyingV4} from "../src/libraries/PancakeUnderlyingV4.sol";
import {PancakeSwapV4} from "../src/libraries/PancakeSwapV4.sol";
import {PIPS, BASE} from "../src/constants/CArrakis.sol";

import {UnderlyingPayload, Range as PoolRange} from "../src/structs/SPancakeSwapV4.sol";

import {PoolKey} from "@pancakeswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@pancakeswap/v4-core/src/types/Currency.sol";
import {PoolIdLibrary} from "@pancakeswap/v4-core/src/types/PoolId.sol";
import {ICLPoolManager} from "@pancakeswap/v4-core/src/pool-cl/interfaces/ICLPoolManager.sol";
import {FullMath} from "@pancakeswap/v4-core/src/pool-cl/libraries/FullMath.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

address constant module = 0x69196b71602D40243b7F5009410B1a4143DF94F7;
address constant vault = 0x0A4233f53328e16db2De5D7cB07AD7dC6457Dd87;
address constant owner = 0x45242F3520cF610ABFFCc0e3315c4fC6080b6154;

contract TotalUnderlying is Script {
    using PoolIdLibrary for PoolKey;

    function setUp() public {}

    function run() public {
        (uint256 amount0, uint256 amount1) =
            IArrakisLPModule(module).totalUnderlying();

        console.log("amount0 :");
        console.log(amount0);
        console.log("amount1 :");
        console.log(amount1);

        IERC20Metadata token0 = IArrakisLPModule(module).token0();
        IERC20Metadata token1 = IArrakisLPModule(module).token1();

        console.logAddress(address(uint160(amount1)));

        // console.log("token0 balance :");
        // console.log(token0.balanceOf(module));
        // console.log("token1 balance :");
        // console.log(token1.balanceOf(module));

        // console.log("token0 decimals :");
        // console.log(token0.decimals());
        // console.log("token1 decimals :");
        // console.log(token1.decimals());

        IPancakeSwapV4StandardModule.Range[] memory ranges =
            IPancakeSwapV4StandardModule(module).getRanges();

        // console.log("ranges :");
        // console.log(ranges.length);


        // for (uint256 i; i < ranges.length; i++) {
        //     console.log("range :");
        //     console.log(ranges[i].tickLower);
        //     console.log(ranges[i].tickUpper);
        // }

        PoolKey memory poolKey;
        (poolKey.currency0, poolKey.currency1, poolKey.hooks, poolKey.poolManager, poolKey.fee, poolKey.parameters) = IPancakeSwapV4StandardModule(module).poolKey();


        uint256 length = ranges.length;
        PoolRange[] memory poolRanges = new PoolRange[](length);
        for (uint256 i; i < length; i++) {
            IPancakeSwapV4StandardModule.Range memory range =
                ranges[i];
            poolRanges[i] = PoolRange({
                lowerTick: range.tickLower,
                upperTick: range.tickUpper,
                poolKey: poolKey
            });
        }

        // console.log("poolKey :");
        // console.logAddress(Currency.unwrap(poolKey.currency0));
        // console.logAddress(Currency.unwrap(poolKey.currency1));
        // console.log(poolKey.fee);
        // console.logAddress(address(poolKey.hooks));
        // console.logAddress(address(poolKey.poolManager));
        // console.logBytes32(poolKey.parameters);

        vm.startPrank(address(module));
        (uint256 leftOver0, uint256 leftOver1) = _getLeftOvers(IPancakeSwapV4StandardModule(module), poolKey);

        address poolManager = address(poolKey.poolManager);

        (uint160 sqrtPriceX96_,,,) =
                ICLPoolManager(poolManager).getSlot0(poolKey.toId());

        console.log("sqrtPriceX96_ :");
        console.log(sqrtPriceX96_);

        (uint256 a0, uint256 a1, uint256 fees0, uint256 fees1) = PancakeUnderlyingV4
                .totalUnderlyingAtPriceWithFees(
                UnderlyingPayload({
                    ranges: poolRanges,
                    poolManager: ICLPoolManager(poolManager),
                    self: module,
                    leftOver0: leftOver0,
                    leftOver1: leftOver1
                }),
                sqrtPriceX96_
            );

        console.log("a0 :");
        console.log(a0);
        console.log("a1 :");
        console.log(a1);
        console.log("fees0 :");
        console.log(fees0);
        console.log("fees1 :");
        console.log(fees1);

        vm.stopPrank();

        uint256 managerFeePIPS = IArrakisLPModule(module).managerFeePIPS();
        uint256 result0 = a0 - FullMath.mulDivRoundingUp(fees0, managerFeePIPS, PIPS);
        uint256 result1 = a1 - FullMath.mulDivRoundingUp(fees1, managerFeePIPS, PIPS);

        console.log("result0 :");
        console.log(result0);
        console.log("result1 :");
        console.log(result1);

        uint256 balance0 = token0.balanceOf(owner);
        uint256 balance1 = token1.balanceOf(owner);

        console.log("balance0 :");
        console.log(balance0);
        console.log("balance1 :");
        console.log(balance1);

        vm.startPrank(owner);
        IArrakisMetaVaultPrivate(vault).withdraw(BASE/2, owner);
        vm.stopPrank();

        uint256 interBalance0 = token0.balanceOf(owner) - balance0;
        uint256 interBalance1 = token1.balanceOf(owner) - balance1;

        console.log("balance0 :");
        console.log(interBalance0);
        console.log("balance1 :");
        console.log(interBalance1);

        vm.startPrank(owner);
        IArrakisMetaVaultPrivate(vault).withdraw(BASE, owner);
        vm.stopPrank();

        console.log("balance0 :");
        console.log(token0.balanceOf(owner) - balance0);
        console.log("balance1 :");
        console.log(token1.balanceOf(owner) - balance1);

        // console.log("leftOver0 :");
        // console.log(leftOver0);
        // console.log("leftOver1 :");
        // console.log(leftOver1);
        
    }

    function _getLeftOvers(
        IPancakeSwapV4StandardModule self_,
        PoolKey memory poolKey_
    ) internal view returns (uint256 leftOver0, uint256 leftOver1) {
        leftOver0 = Currency.unwrap(poolKey_.currency0) == address(0)
            ? address(self_).balance
            : IERC20Metadata(Currency.unwrap(poolKey_.currency0))
                .balanceOf(address(self_));
        leftOver1 = IERC20Metadata(
            Currency.unwrap(poolKey_.currency1)
        ).balanceOf(address(self_));
    }
}
