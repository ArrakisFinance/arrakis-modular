// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// #region foundry.
import {console} from "forge-std/console.sol";
import {TestWrapper} from "../../utils/TestWrapper.sol";
// #endregion foundry.

// #region Uniswap Resolver.

import {UniV4StandardModuleResolver} from
    "../../../src/modules/resolvers/UniV4StandardModuleResolver.sol";
import {IUniV4StandardModuleResolver} from
    "../../../src/interfaces/IUniV4StandardModuleResolver.sol";
import {IResolver} from "../../../src/interfaces/IResolver.sol";
import {IArrakisMetaVault} from "../../../src/interfaces/IArrakisMetaVault.sol";
import {IArrakisLPModule} from "../../../src/interfaces/IArrakisLPModule.sol";

// #endregion Uniswap Resolver.

// #region uniswap v4.

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";

// #endregion uniswap v4.

// #region mock contracts.

import {Module} from "./mocks/Module.sol";
import {MetaVault} from "./mocks/MetaVault.sol";

// #endregion mock contracts.

contract UniV4StandardModuleResolverTest is TestWrapper {
    address public constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant WETH =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant poolManager =
        0x000000000004444c5dc75cB358380D2e3dE08A90;

    IArrakisMetaVault public metaVault;
    IArrakisLPModule public module;
    UniV4StandardModuleResolver public resolver;

    function setUp() public {
        _reset(vm.envString("ETH_RPC_URL"), 21688330);
        module = IArrakisLPModule(address(new Module()));
        metaVault = IArrakisMetaVault(address(new MetaVault()));
        MetaVault(address(metaVault)).setModule(module);

        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(USDC),
            currency1: Currency.wrap(WETH),
            fee: 500,
            tickSpacing: 10,
            hooks: IHooks(address(0))
        });

        Module(address(module)).setPoolKey(poolKey);

        resolver = new UniV4StandardModuleResolver(poolManager);
    }

    function test_getBurnAmounts_vault_address_zero() public {
        vm.expectRevert(IUniV4StandardModuleResolver.AddressZero.selector);
        resolver.getBurnAmounts(address(0), 100);
    }

    function test_getBurnAmounts_shares_zero() public {
        vm.expectRevert(IUniV4StandardModuleResolver.SharesZero.selector);
        resolver.getBurnAmounts(address(metaVault), 0);
    }

    function test_getBurnAmounts_shares_total_supply_zero() public {
        vm.expectRevert(IResolver.TotalSupplyZero.selector);
        resolver.getBurnAmounts(address(metaVault), 100);
    }

    function test_getBurnAmounts_shares_over_total_supply() public {
        MetaVault(address(metaVault)).setTotalSupply(1e18);
        vm.expectRevert(IResolver.SharesOverTotalSupply.selector);
        resolver.getBurnAmounts(address(metaVault), 100e18);
    }
}
