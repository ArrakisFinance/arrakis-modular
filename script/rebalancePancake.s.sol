// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {IArrakisMetaVaultPrivate} from
    "../src/interfaces/IArrakisMetaVaultPrivate.sol";
import {IArrakisMetaVault} from
    "../src/interfaces/IArrakisMetaVault.sol";
import {SwapPayload} from "../src/structs/SPancakeSwapV4.sol";
import {IPancakeSwapV4StandardModule} from
    "../src/interfaces/IPancakeSwapV4StandardModule.sol";
import {IArrakisStandardManager} from
    "../src/interfaces/IArrakisStandardManager.sol";
import {VaultInfo, SetupParams} from "../src/structs/SManager.sol";

// #region pancake swap v4.

import {ICLPoolManager} from
    "@pancakeswap/v4-core/src/pool-cl/interfaces/ICLPoolManager.sol";
import {TickMath} from
    "@pancakeswap/v4-core/src/pool-cl/libraries/TickMath.sol";
import {PoolId} from "@pancakeswap/v4-core/src/types/PoolId.sol";

// #endregion pancake swap v4.

import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeCast} from
    "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {LiquidityAmounts} from
    "@v3-lib-0.8/contracts/LiquidityAmounts.sol";

address constant vault = 0x931Ea526B8e2E0A76217B6b704B99cC977B32c5E;
address constant manager = 0x2e6E879648293e939aA68bA4c6c129A1Be733bDA;
address constant poolManager =
    0xa0FfB9c1CE1Fe56963B0321B32E7A0302114058b;
bytes32 constant poolId =
    0x82941339084b705b3ebb5817edd6b6870f6393d27e6d1da687e943ff0d48cef5;
uint256 constant amount0 = 0.018 ether;
uint256 constant amount1 = 39 * (10 ** 18);

contract RebalancePancake is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        console.log(msg.sender);

        // #region become executor.

        console.log("token0 : ");
        console.logAddress(IArrakisMetaVault(vault).token0());
        console.log("token1 : ");
        console.logAddress(IArrakisMetaVault(vault).token1());

        VaultInfo memory vaultInfo;
        (
            ,
            vaultInfo.cooldownPeriod,
            vaultInfo.oracle,
            vaultInfo.maxDeviation,
            ,
            vaultInfo.stratAnnouncer,
            vaultInfo.maxSlippagePIPS,
        ) = IArrakisStandardManager(manager).vaultInfo(vault);

        IArrakisStandardManager(manager).updateVaultInfo(
            SetupParams({
                vault: vault,
                oracle: vaultInfo.oracle,
                maxDeviation: vaultInfo.maxDeviation,
                cooldownPeriod: vaultInfo.cooldownPeriod,
                executor: msg.sender,
                stratAnnouncer: vaultInfo.stratAnnouncer,
                maxSlippagePIPS: vaultInfo.maxSlippagePIPS
            })
        );

        // #endregion become executor.

        // #region do rebalance.

        (
            uint160 sqrtPriceX96,
            int24 tick,
            uint24 protocolFee,
            uint24 lpFee
        ) = ICLPoolManager(poolManager).getSlot0(PoolId.wrap(poolId));

        int24 lowerTick = ((tick - 1000)/10) * 10;
        int24 upperTick = ((tick + 1000)/10) * 10;

        IPancakeSwapV4StandardModule.LiquidityRange[] memory ranges =
            new IPancakeSwapV4StandardModule.LiquidityRange[](1);

        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(lowerTick),
            TickMath.getSqrtRatioAtTick(upperTick),
            amount0,
            amount1
        );

        console.logUint(liquidity);

        uint256 amt0 = LiquidityAmounts.getAmount0ForLiquidity(TickMath.getSqrtRatioAtTick(lowerTick),
            TickMath.getSqrtRatioAtTick(upperTick), liquidity);

        console.log("Amount0: ", amt0);
        uint256 amt1 = LiquidityAmounts.getAmount1ForLiquidity(TickMath.getSqrtRatioAtTick(lowerTick),
            TickMath.getSqrtRatioAtTick(upperTick), liquidity);
        console.log("Amount1: ", amt1);

        ranges[0] = IPancakeSwapV4StandardModule.LiquidityRange({
            range: IPancakeSwapV4StandardModule.Range({
                tickLower: lowerTick,
                tickUpper: upperTick
            }),
            liquidity: SafeCast.toInt128(
                SafeCast.toInt256(uint256(liquidity))
            )
        });

        address module = address(IArrakisMetaVault(vault).module());

        console.logAddress(module);

        SwapPayload memory payload;

        bytes[] memory payloads_ = new bytes[](1);
        payloads_[0] = abi.encodeWithSelector(
            IPancakeSwapV4StandardModule.rebalance.selector,
            ranges,
            payload,
            0,
            0,
            0,
            0
        );

        IArrakisStandardManager(manager).rebalance(vault, payloads_);

        // #endregion do rebalance.

        vm.stopBroadcast();
    }
}
