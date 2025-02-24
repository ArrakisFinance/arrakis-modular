// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

// #region foundry.
import {console} from "forge-std/console.sol";
import {TestWrapper} from "../../utils/TestWrapper.sol";
// #endregion foundry.

import {MigrationHelper} from "../../../src/utils/MigrationHelper.sol";
import {IMigrationHelper} from
    "../../../src/interfaces/IMigrationHelper.sol";
import {IArrakisV2} from "../../../src/interfaces/IArrakisV2.sol";

import {Ownable} from "@solady/contracts/auth/Ownable.sol";

// #region uniswap v4.

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {
    Currency,
    CurrencyLibrary
} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// #endregion uniswap v4.

// #region mock smart contracts.

import {SafeMock} from "./mocks/SafeMock.sol";
import {ArrakisMetaVaultFactoryMock} from
    "./mocks/ArrakisMetaVaultFactory.sol";
import {ArrakisV2Mock} from "./mocks/ArrakisV2.sol";
import {ArrakisStandardManagerMock} from
    "./mocks/ArrakisStandardManager.sol";

// #endregion mock smart contracts.

contract MigrationHelperTest is TestWrapper {
    using CurrencyLibrary for Currency;

    // #region constant.

    address public constant WETH =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDT =
        0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public constant USDX =
        0xf3527ef8dE265eAa3716FB312c12847bFBA66Cef;

    //#endregion constant.

    MigrationHelper public migrationHelper;

    address public palmTerms;
    address public factory;
    address public safe;
    address public manager;
    address public poolManager;
    address public owner;

    function setUp() public {
        // #region reset fork.

        _reset(vm.envString("ETH_RPC_URL"), 21_906_539);

        // #endregion reset fork.

        // #region mocks.

        palmTerms =
            vm.addr(uint256(keccak256(abi.encode("PALMTerms"))));
        poolManager =
            vm.addr(uint256(keccak256(abi.encode("PoolManager"))));
        owner = vm.addr(uint256(keccak256(abi.encode("Owner"))));

        safe = address(new SafeMock(WETH, USDC));

        manager = address(new ArrakisStandardManagerMock());

        factory = address(new ArrakisMetaVaultFactoryMock());

        // #endregion mocks.
    }

    // #region test constructor.

    function test_constructor_palmTerms_Address_Zero() public {
        vm.expectRevert(IMigrationHelper.AddressZero.selector);

        migrationHelper = new MigrationHelper(
            address(0), factory, manager, poolManager, WETH, owner
        );
    }

    function test_constructor_factory_Address_Zero() public {
        vm.expectRevert(IMigrationHelper.AddressZero.selector);

        migrationHelper = new MigrationHelper(
            palmTerms, address(0), manager, poolManager, WETH, owner
        );
    }

    function test_constructor_manager_Address_Zero() public {
        vm.expectRevert(IMigrationHelper.AddressZero.selector);

        migrationHelper = new MigrationHelper(
            palmTerms, factory, address(0), poolManager, WETH, owner
        );
    }

    function test_constructor_poolManager_Address_Zero() public {
        vm.expectRevert(IMigrationHelper.AddressZero.selector);

        migrationHelper = new MigrationHelper(
            palmTerms, factory, manager, address(0), WETH, owner
        );
    }

    function test_constructor_weth_Address_Zero() public {
        vm.expectRevert(IMigrationHelper.AddressZero.selector);

        migrationHelper = new MigrationHelper(
            palmTerms,
            factory,
            manager,
            poolManager,
            address(0),
            owner
        );
    }

    function test_constructor_owner_Address_Zero() public {
        vm.expectRevert(IMigrationHelper.AddressZero.selector);

        migrationHelper = new MigrationHelper(
            palmTerms, factory, manager, poolManager, WETH, address(0)
        );
    }

    // #endregion test constructor.

    // #region test migrate vault function.

    function test_migrate_vault_unauthorized() public {
        migrationHelper = new MigrationHelper(
            palmTerms, factory, manager, poolManager, WETH, owner
        );

        IMigrationHelper.Migration memory migration;

        vm.expectRevert(Ownable.Unauthorized.selector);
        migrationHelper.migrateVault(migration);
    }

    function test_migrate_vault_withdraw_error() public {
        migrationHelper = new MigrationHelper(
            palmTerms, factory, manager, poolManager, WETH, owner
        );

        // #region poolKey.

        PoolKey memory poolKey = PoolKey({
            currency0: CurrencyLibrary.ADDRESS_ZERO,
            currency1: Currency.wrap(USDT),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });

        // #endregion poolKey.

        // #region safe mock.

        safe = address(new SafeMock(WETH, USDT));
        SafeMock(safe).setAmounts(1e18, 2740e6);
        SafeMock(safe).setRevertStep(2);

        // #endregion safe mock.

        // #region v2 vault.

        ArrakisV2Mock vaultV2 = new ArrakisV2Mock();
        vaultV2.setTokens(IERC20(WETH), IERC20(USDT));

        // #endregion v2 vault.

        // #region create migration struct.

        MigrationHelper.Migration memory migration;

        migration.poolCreation.poolKey = poolKey;
        migration.safe = safe;
        migration.closeTerm.vault = IArrakisV2(address(vaultV2));

        // #endregion create migration struct.

        vm.prank(safe);
        vm.expectRevert(IMigrationHelper.WithdrawETH.selector);
        migrationHelper.migrateVault(migration);
    }

    function test_migrate_vault_withdraw_error_case_1() public {
        migrationHelper = new MigrationHelper(
            palmTerms, factory, manager, poolManager, WETH, owner
        );

        // #region poolKey.

        PoolKey memory poolKey = PoolKey({
            currency0: CurrencyLibrary.ADDRESS_ZERO,
            currency1: Currency.wrap(USDX),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });

        // #endregion poolKey.

        // #region safe mock.

        safe = address(new SafeMock(WETH, USDX));
        SafeMock(safe).setAmounts(1e18, 2740e18);
        SafeMock(safe).setRevertStep(2);

        // #endregion safe mock.

        // #region v2 vault.

        ArrakisV2Mock vaultV2 = new ArrakisV2Mock();
        vaultV2.setTokens(IERC20(WETH), IERC20(USDX));

        // #endregion v2 vault.

        // #region create migration struct.

        MigrationHelper.Migration memory migration;

        migration.poolCreation.poolKey = poolKey;
        migration.safe = safe;
        migration.closeTerm.vault = IArrakisV2(address(vaultV2));

        // #endregion create migration struct.

        vm.prank(safe);
        vm.expectRevert(IMigrationHelper.WithdrawETH.selector);
        migrationHelper.migrateVault(migration);
    }

    function test_migrate_vault_withdraw_error_case_2() public {
        migrationHelper = new MigrationHelper(
            palmTerms, factory, manager, poolManager, WETH, owner
        );

        // #region poolKey.

        PoolKey memory poolKey = PoolKey({
            currency0: CurrencyLibrary.ADDRESS_ZERO,
            currency1: Currency.wrap(USDX),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });

        // #endregion poolKey.

        // #region safe mock.

        safe = address(new SafeMock(USDX, WETH));
        SafeMock(safe).setAmounts(2740e18, 1e18);
        SafeMock(safe).setRevertStep(2);

        // #endregion safe mock.

        // #region v2 vault.

        ArrakisV2Mock vaultV2 = new ArrakisV2Mock();
        vaultV2.setTokens(IERC20(USDX), IERC20(WETH));

        // #endregion v2 vault.

        // #region create migration struct.

        MigrationHelper.Migration memory migration;

        migration.poolCreation.poolKey = poolKey;
        migration.safe = safe;
        migration.closeTerm.vault = IArrakisV2(address(vaultV2));

        // #endregion create migration struct.

        vm.prank(safe);
        vm.expectRevert(IMigrationHelper.WithdrawETH.selector);
        migrationHelper.migrateVault(migration);
    }

    function test_migrate_vault_whitelist_depositor_error() public {
        migrationHelper = new MigrationHelper(
            palmTerms, factory, manager, poolManager, WETH, owner
        );

        // #region poolKey.

        PoolKey memory poolKey = PoolKey({
            currency0: CurrencyLibrary.ADDRESS_ZERO,
            currency1: Currency.wrap(USDX),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });

        // #endregion poolKey.

        // #region safe mock.

        safe = address(new SafeMock(USDX, WETH));
        SafeMock(safe).setAmounts(2740e18, 1e18);
        SafeMock(safe).setRevertStep(3);

        // #endregion safe mock.

        // #region v2 vault.

        ArrakisV2Mock vaultV2 = new ArrakisV2Mock();
        vaultV2.setTokens(IERC20(USDX), IERC20(WETH));

        // #endregion v2 vault.

        // #region create migration struct.

        MigrationHelper.Migration memory migration;

        migration.poolCreation.poolKey = poolKey;
        migration.safe = safe;
        migration.closeTerm.vault = IArrakisV2(address(vaultV2));

        // #endregion create migration struct.

        vm.prank(safe);
        vm.expectRevert(
            IMigrationHelper.WhitelistDepositorErr.selector
        );
        migrationHelper.migrateVault(migration);
    }

    function test_migrate_vault_approval_error_case_0() public {
        migrationHelper = new MigrationHelper(
            palmTerms, factory, manager, poolManager, WETH, owner
        );

        // #region poolKey.

        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(WETH),
            currency1: Currency.wrap(USDX),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });

        // #endregion poolKey.

        // #region safe mock.

        safe = address(new SafeMock(WETH, USDX));
        SafeMock(safe).setAmounts(1e18, 0);
        SafeMock(safe).setRevertStep(4);

        // #endregion safe mock.

        // #region v2 vault.

        ArrakisV2Mock vaultV2 = new ArrakisV2Mock();
        vaultV2.setTokens(IERC20(WETH), IERC20(USDX));

        // #endregion v2 vault.

        // #region create migration struct.

        MigrationHelper.Migration memory migration;

        migration.poolCreation.poolKey = poolKey;
        migration.safe = safe;
        migration.closeTerm.vault = IArrakisV2(address(vaultV2));

        // #endregion create migration struct.

        vm.prank(safe);
        vm.expectRevert(IMigrationHelper.Approval0Err.selector);
        migrationHelper.migrateVault(migration);
    }

    function test_migrate_vault_approval_error_case_1() public {
        migrationHelper = new MigrationHelper(
            palmTerms, factory, manager, poolManager, WETH, owner
        );

        // #region poolKey.

        PoolKey memory poolKey = PoolKey({
            currency0: CurrencyLibrary.ADDRESS_ZERO,
            currency1: Currency.wrap(USDX),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });

        // #endregion poolKey.

        // #region safe mock.

        safe = address(new SafeMock(USDX, WETH));
        SafeMock(safe).setAmounts(2740e18, 0);
        SafeMock(safe).setRevertStep(4);

        // #endregion safe mock.

        // #region v2 vault.

        ArrakisV2Mock vaultV2 = new ArrakisV2Mock();
        vaultV2.setTokens(IERC20(USDX), IERC20(WETH));

        // #endregion v2 vault.

        // #region create migration struct.

        MigrationHelper.Migration memory migration;

        migration.poolCreation.poolKey = poolKey;
        migration.safe = safe;
        migration.closeTerm.vault = IArrakisV2(address(vaultV2));

        // #endregion create migration struct.

        vm.prank(safe);
        vm.expectRevert(IMigrationHelper.Approval1Err.selector);
        migrationHelper.migrateVault(migration);
    }

    function test_migrate_vault_depositor_error() public {
        migrationHelper = new MigrationHelper(
            palmTerms, factory, manager, poolManager, WETH, owner
        );

        // #region poolKey.

        PoolKey memory poolKey = PoolKey({
            currency0: CurrencyLibrary.ADDRESS_ZERO,
            currency1: Currency.wrap(USDX),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });

        // #endregion poolKey.

        // #region safe mock.

        safe = address(new SafeMock(USDX, WETH));
        SafeMock(safe).setAmounts(2740e18, 1e18);
        SafeMock(safe).setRevertStep(5);

        // #endregion safe mock.

        // #region v2 vault.

        ArrakisV2Mock vaultV2 = new ArrakisV2Mock();
        vaultV2.setTokens(IERC20(USDX), IERC20(WETH));

        // #endregion v2 vault.

        // #region create migration struct.

        MigrationHelper.Migration memory migration;

        migration.poolCreation.poolKey = poolKey;
        migration.safe = safe;
        migration.closeTerm.vault = IArrakisV2(address(vaultV2));

        // #endregion create migration struct.

        vm.prank(safe);
        vm.expectRevert(IMigrationHelper.DepositErr.selector);
        migrationHelper.migrateVault(migration);
    }

    function test_migrate_vault_rebalance_error() public {
        migrationHelper = new MigrationHelper(
            palmTerms, factory, manager, poolManager, WETH, owner
        );

        // #region poolKey.

        PoolKey memory poolKey = PoolKey({
            currency0: CurrencyLibrary.ADDRESS_ZERO,
            currency1: Currency.wrap(USDX),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });

        // #endregion poolKey.

        // #region safe mock.

        safe = address(new SafeMock(USDX, WETH));
        SafeMock(safe).setAmounts(2740e18, 1e18);
        SafeMock(safe).setRevertStep(6);

        // #endregion safe mock.

        // #region v2 vault.

        ArrakisV2Mock vaultV2 = new ArrakisV2Mock();
        vaultV2.setTokens(IERC20(USDX), IERC20(WETH));

        // #endregion v2 vault.

        // #region create migration struct.

        MigrationHelper.Migration memory migration;

        migration.poolCreation.poolKey = poolKey;
        migration.safe = safe;
        migration.closeTerm.vault = IArrakisV2(address(vaultV2));
        migration.rebalancePayloads = new bytes[](1);

        // #endregion create migration struct.

        vm.prank(safe);
        vm.expectRevert(IMigrationHelper.RebalanceErr.selector);
        migrationHelper.migrateVault(migration);
    }

    function test_migrate_vault_change_executor_error() public {
        migrationHelper = new MigrationHelper(
            palmTerms, factory, manager, poolManager, WETH, owner
        );

        // #region poolKey.

        PoolKey memory poolKey = PoolKey({
            currency0: CurrencyLibrary.ADDRESS_ZERO,
            currency1: Currency.wrap(USDX),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });

        // #endregion poolKey.

        // #region safe mock.

        safe = address(new SafeMock(USDX, WETH));
        SafeMock(safe).setAmounts(2740e18, 1e18);
        SafeMock(safe).setRevertStep(7);

        // #endregion safe mock.

        // #region v2 vault.

        ArrakisV2Mock vaultV2 = new ArrakisV2Mock();
        vaultV2.setTokens(IERC20(USDX), IERC20(WETH));

        // #endregion v2 vault.

        // #region create migration struct.

        MigrationHelper.Migration memory migration;

        migration.poolCreation.poolKey = poolKey;
        migration.safe = safe;
        migration.closeTerm.vault = IArrakisV2(address(vaultV2));
        migration.rebalancePayloads = new bytes[](1);

        // #endregion create migration struct.

        vm.prank(safe);
        vm.expectRevert(IMigrationHelper.ChangeExecutorErr.selector);
        migrationHelper.migrateVault(migration);
    }

    // #endregion test migrate vault function.
}
