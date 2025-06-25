// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;
/* 
import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

// #region Arrakis.

import {IArrakisStandardManager} from
    "../src/interfaces/IArrakisStandardManager.sol";
import {IArrakisMetaVault} from
    "../src/interfaces/IArrakisMetaVault.sol";
import {
    IUniV4StandardModule,
    SwapPayload
} from "../src/interfaces/IUniV4StandardModule.sol";
import {IArrakisPrivateHookFactory} from
    "../src/interfaces/IArrakisPrivateHookFactory.sol";

// #endregion Arrakis.

// #region Uniswap V4.

import {IPoolManager} from
    "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {
    PoolId,
    PoolIdLibrary
} from "@uniswap/v4-core/src/types/PoolId.sol";
import {StateLibrary} from
    "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {
    Hooks, IHooks
} from "@uniswap/v4-core/src/libraries/Hooks.sol";

// #endregion Uniswap V4.

import {Create3} from "@create3/contracts/Create3.sol";

import {SafeCast} from
    "@openzeppelin/contracts/utils/math/SafeCast.sol";

address constant PoolManager =
    0x000000000004444c5dc75cB358380D2e3dE08A90;
address constant GELVault = 0x706Fc1ADdAA9D63663eE98A8fCb4a61dC48C458c;
address constant Executor = 0x420966bCf2A0351F26048cD07076627Cde4f79ac;
address constant manager = 0x2e6E879648293e939aA68bA4c6c129A1Be733bDA;
address constant hookFactory =
    0xeF129a430032C8183abA158C1a70799e3b840dF9;

contract SetHookPoolKey is Script {
    using StateLibrary for IPoolManager;
    using PoolIdLibrary for PoolKey;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        console.logString("Transaction executor :");
        console.logAddress(msg.sender);

        address module = address(IArrakisMetaVault(GELVault).module());

        PoolKey memory poolKey;
        (
            poolKey.currency0,
            poolKey.currency1,
            poolKey.fee,
            poolKey.tickSpacing,
            poolKey.hooks
        ) = IUniV4StandardModule(module).poolKey();

        PoolId poolId = poolKey.toId();

        IPoolManager poolManager = IPoolManager(PoolManager);

        (uint160 sqrtPriceX96,,,) = poolManager.getSlot0(poolId);

        console.log("Sqrt price X96 of current pool : ", sqrtPriceX96);

        // #region create new hook.

        IArrakisPrivateHookFactory factory =
            IArrakisPrivateHookFactory(hookFactory);

        bytes32 salt;
        bytes32 s;

        Hooks.Permissions memory perm = Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: true,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });

        ValidAddr validAddr =
            new ValidAddr();

        for (uint256 i = 0; i < 10_000; i++) {
            salt = keccak256(abi.encode(msg.sender, bytes32(i)));

            address hookAddr = factory.addressOf(salt);

            try validAddr.valideAddr(IHooks(hookAddr), perm) {
                s = bytes32(i);
                break;
            } catch {
                salt = bytes32(0);
                continue;
            }
        }

        if (salt == bytes32(0)) {
            vm.expectRevert(Create3.ErrorCreatingContract.selector);
        } else {
            console.logBytes32(salt);
            console.logBytes32(s);
        }

        address hook = IArrakisPrivateHookFactory(hookFactory)
            .createPrivateHook(module, s);

        // #endregion create new hook.

        // #region create the new pool.

        poolKey.hooks = IHooks(hook);

        poolManager.initialize(poolKey, sqrtPriceX96);

        // #endregion create the new pool.

        // #region set the pool key.

        IUniV4StandardModule.Range[] memory ranges =
            IUniV4StandardModule(module).getRanges();

        IUniV4StandardModule.LiquidityRange[] memory liquidityRanges =
            new IUniV4StandardModule.LiquidityRange[](ranges.length);

        for (uint256 i = 0; i < ranges.length; i++) {
            (uint128 liquidity,,) = poolManager.getPositionInfo(
                poolId,
                module,
                ranges[i].tickLower,
                ranges[i].tickUpper,
                ""
            );

            liquidityRanges[i] = IUniV4StandardModule.LiquidityRange({
                range: IUniV4StandardModule.Range({
                    tickLower: ranges[i].tickLower,
                    tickUpper: ranges[i].tickUpper
                }),
                liquidity: SafeCast.toInt128(
                    SafeCast.toInt256(uint256(liquidity))
                )
            });
        }

        SwapPayload memory swapPayload;

        vm.stopBroadcast();
        vm.startBroadcast(manager);

        IUniV4StandardModule(module).setPool(
            poolKey, liquidityRanges, swapPayload, 0, 0, 0, 0
        );

        // #endregion set the pool key.
        vm.stopBroadcast();

    }
}

contract ValidAddr {
    function valideAddr(
        IHooks hooks,
        Hooks.Permissions memory perm
    ) external pure returns (bool) {
        Hooks.validateHookPermissions(hooks, perm);
    }
}
 */