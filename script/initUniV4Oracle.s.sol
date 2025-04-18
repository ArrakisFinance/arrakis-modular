// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";

import {IUniV4Oracle} from "../src/interfaces/IUniV4Oracle.sol";
import {IArrakisMetaVault} from
    "../src/interfaces/IArrakisMetaVault.sol";
import {IArrakisMetaVaultPrivate} from
    "../src/interfaces/IArrakisMetaVaultPrivate.sol";
import {IArrakisPrivateHookFactory} from
    "../src/interfaces/IArrakisPrivateHookFactory.sol";
import {IArrakisStandardManager} from
    "../src/interfaces/IArrakisStandardManager.sol";
import {IUniV4StandardModule} from
    "../src/interfaces/IUniV4StandardModule.sol";
import {SwapPayload} from "../src/structs/SUniswapV4.sol";
import {NATIVE_COIN} from "../src/constants/CArrakis.sol";

import {IPoolManager} from
    "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {
    PoolKey, Currency
} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {CurrencyLibrary} from
    "@uniswap/v4-core/src/types/Currency.sol";
import {
    PoolId,
    PoolIdLibrary
} from "@uniswap/v4-core/src/types/PoolId.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {StateLibrary} from
    "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";

import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// IMPORTANT !!! Fill in / check these sensitive varaibles before running script !!!$

address constant oracle = 0x2B1FF675dfaED19eDd185ac5cdc699095Eb9E3Dd;
address constant vault = 0x39fa8Ef31E8ef492435c5288AE8e476f3E370267;

address constant hookFactory =
    0xeF129a430032C8183abA158C1a70799e3b840dF9;

address constant poolManager =
    0x498581fF718922c3f8e6A244956aF099B2652b2b;

address constant token0 = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
address constant token1 = NATIVE_COIN;
uint24 constant fee = 500;
int24 constant tickSpacing = 10;

bool constant isInversed = true;

address constant manager = 0x2e6E879648293e939aA68bA4c6c129A1Be733bDA;

contract InitUniV4Oracle is Script {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        console.log("Deployer : ");
        console.logAddress(msg.sender);

        IUniV4Oracle uniV4Oracle = IUniV4Oracle(oracle);
        IArrakisMetaVault arrakisMetaVault = IArrakisMetaVault(vault);

        address module = address(arrakisMetaVault.module());

        // uniV4Oracle.initialize(module);

        // #region salt computation.

        // bytes32 salt;
        // bytes32 s;

        // Hooks.Permissions memory perm = Hooks.Permissions({
        //     beforeInitialize: false,
        //     afterInitialize: false,
        //     beforeAddLiquidity: true,
        //     afterAddLiquidity: false,
        //     beforeRemoveLiquidity: false,
        //     afterRemoveLiquidity: false,
        //     beforeSwap: true,
        //     afterSwap: false,
        //     beforeDonate: false,
        //     afterDonate: false,
        //     beforeSwapReturnDelta: false,
        //     afterSwapReturnDelta: false,
        //     afterAddLiquidityReturnDelta: false,
        //     afterRemoveLiquidityReturnDelta: false
        // });

        // for (uint256 i = 0; i < 100_000; i++) {
        //     salt = keccak256(abi.encode(msg.sender, bytes32(i)));
        //     address hookAddr = IArrakisPrivateHookFactory(hookFactory).addressOf(salt);

        //     try this.valideAddr(IHooks(hookAddr), perm) {
        //         s = bytes32(i);
        //         break;
        //     } catch {
        //         salt = bytes32(0);
        //         continue;
        //     }
        // }

        // if (salt == bytes32(0)) {
        //     revert("ErrorCreatingContract");
        // } else {
        //     console.logBytes32(salt);
        //     console.logBytes32(s);
        // }

        // #endregion salt computation.

        address hook = IArrakisPrivateHookFactory(hookFactory)
            .createPrivateHook(module, 0x0000000000000000000000000000000000000000000000000000000000001d84);

        console.log("Hook : ");
        console.logAddress(hook);

        // #region create new pool.

        PoolKey memory poolKey;

        if (isInversed) {
            poolKey = PoolKey({
                currency0: CurrencyLibrary.ADDRESS_ZERO,
                currency1: Currency.wrap(token0),
                fee: fee,
                tickSpacing: tickSpacing,
                hooks: IHooks(address(0))
            });
        } else {
            poolKey = PoolKey({
                currency0: CurrencyLibrary.ADDRESS_ZERO,
                currency1: Currency.wrap(token1),
                fee: fee,
                tickSpacing: tickSpacing,
                hooks: IHooks(address(0))
            });
        }

        PoolId poolId = poolKey.toId();

        console.log("Pool Id : ");
        console.logBytes32(PoolId.unwrap(poolId));

        (uint160 sqrtPriceX96,,,) =
            IPoolManager(poolManager).getSlot0(poolId);

        poolKey.hooks = IHooks(hook);

        IPoolManager(poolManager).initialize(poolKey, sqrtPriceX96);

        // #endregion create new pool.

        // #region whitelist depositor.

        address[] memory whitelistDepositors =
            new address[](1);
        whitelistDepositors[0] = msg.sender;

        IArrakisMetaVaultPrivate(vault).whitelistDepositors(
            whitelistDepositors
        );

        // #endregion whitelist depositor.

        // #region deposit 1 wei.

        uint256 amount0 = 1;
        uint256 amount1 = 1;

        // #region approve tokens.

        IERC20Metadata(token0).approve(
            module,
            amount0
        );

        // #endregion approve tokens.

        IArrakisMetaVaultPrivate(vault).deposit{value: 1}(
            amount0,
            amount1
        );

        // #endregion deposit 1 wei.

        // #region set the new pool on module.

        IUniV4StandardModule.LiquidityRange[] memory ranges =
            new IUniV4StandardModule.LiquidityRange[](0);

        SwapPayload memory swapPayload;

        bytes memory payload = abi.encodeWithSelector(
            IUniV4StandardModule.setPool.selector,
            poolKey,
            ranges,
            swapPayload,
            0,
            0,
            0,
            0
        );

        bytes[] memory payloads = new bytes[](1);
        payloads[0] = payload;

        IArrakisStandardManager(manager).rebalance(vault, payloads);

        // #endregion set the new pool on module.

        vm.stopBroadcast();
    }

    function valideAddr(
        IHooks hooks,
        Hooks.Permissions memory perm
    ) external returns (bool) {
        Hooks.validateHookPermissions(hooks, perm);
    }
}
