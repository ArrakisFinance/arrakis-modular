// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

// #region foundry.
import {TestWrapper} from "../utils/TestWrapper.sol";
import {console} from "forge-std/console.sol";
// #endregion foundry.

// #region interfaces.

import {IArrakisMetaVaultFactory} from
    "../../src/interfaces/IArrakisMetaVaultFactory.sol";
import {IArrakisPrivateVaultRouter} from
    "../../src/interfaces/IArrakisPrivateVaultRouter.sol";
import {IArrakisStandardManager} from
    "../../src/interfaces/IArrakisStandardManager.sol";
import {IGuardian} from "../../src/interfaces/IGuardian.sol";
import {IModuleRegistry} from
    "../../src/interfaces/IModuleRegistry.sol";
import {IPauser} from "../../src/interfaces/IPauser.sol";
import {IUniV4StandardModule} from
    "../../src/interfaces/IUniV4StandardModule.sol";
import {IOracleWrapper} from "../../src/interfaces/IOracleWrapper.sol";
import {IUniV4StandardModuleResolver} from
    "../../src/interfaces/IUniV4StandardModuleResolver.sol";
import {IOwnable} from "../../src/interfaces/IOwnable.sol";
import {
    NATIVE_COIN,
    TEN_PERCENT,
    PIPS
} from "../../src/constants/CArrakis.sol";
import {ArrakisPrivateVaultRouter} from
    "../../src/ArrakisPrivateVaultRouter.sol";
import {PrivateRouterSwapExecutor} from
    "../../src/PrivateRouterSwapExecutor.sol";
import {UniV4StandardModulePrivate} from
    "../../src/modules/UniV4StandardModulePrivate.sol";
import {IArrakisMetaVaultPrivate} from
    "../../src/interfaces/IArrakisMetaVaultPrivate.sol";
import {IArrakisMetaVault} from
    "../../src/interfaces/IArrakisMetaVault.sol";
import {
    WithdrawHelper,
    IWithdrawHelper
} from "../../src/utils/WithdrawHelper.sol";
import {
    MigrationHelper,
    IMigrationHelper
} from "../../src/utils/MigrationHelper.sol";
import {IArrakisV2} from "../../src/interfaces/IArrakisV2.sol";
import {SwapPayload} from "../../src/structs/SUniswapV4.sol";

// #endregion interfaces.

// #region openzeppelin.

import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {UpgradeableBeacon} from
    "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {SafeCast} from
    "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {IERC721Receiver} from
    "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

// #endregion openzeppelin.

// #region uniswap v4.

import {
    PoolManager,
    IPoolManager
} from "@uniswap/v4-core/src/PoolManager.sol";
import {
    Currency,
    CurrencyLibrary
} from "@uniswap/v4-core/src/types/Currency.sol";
import {
    PoolKey,
    PoolIdLibrary
} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";

// #endregion uniswap v4.

import {LiquidityAmounts} from
    "@v3-lib-0.8/contracts/LiquidityAmounts.sol";
import {FullMath} from
    "@v3-lib-0.8/contracts/FullMath.sol";

// #region mocks.

import {OracleWrapper} from "./mocks/OracleWrapper.sol";
import {IGnosisSafeProxyFactory} from
    "./mocks/IGnosisSafeProxyFactory.sol";
import {GnosisSafeProxy} from "./mocks/GnosisSafeProxy.sol";
import {IGnosisSafe, Operation} from "./mocks/IGnosisSafe.sol";

// #endregion mocks.

interface IUniswapV3PoolState {
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        );
}

contract UniswapV4PrivateIntegration is TestWrapper {
    using SafeERC20 for IERC20Metadata;
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;

    // #region constant properties.
    address public constant WETH =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    // #endregion constant properties.

    // #region arrakis modular contracts.

    address public constant arrakisStandardManager =
        0x2e6E879648293e939aA68bA4c6c129A1Be733bDA;
    address public constant arrakisTimeLock =
        0xAf6f9640092cB1236E5DB6E517576355b6C40b7f;
    address public constant factory =
        0x820FB8127a689327C863de8433278d6181123982;
    address public constant privateVaultNFT =
        0x44A801e7E2E073bd8bcE4bCCf653239Fa156B762;
    address public constant guardian =
        0x6F441151B478E0d60588f221f1A35BcC3f7aB981;
    address public constant publicRegistry =
        0x791d75F87a701C3F7dFfcEC1B6094dB22c779603;
    address public constant privateRegistry =
        0xe278C1944BA3321C1079aBF94961E9fF1127A265;
    address public constant pauser =
        0xfae375Bc5060A51343749CEcF5c8ABe65F11cCAC;

    // #endregion arrakis modular contracts.

    // #region arrakis v2 contract.

    address public constant GELV2Vault =
        0xd42dd60fbE8331413383075ac91EDE56784e93D3;
    address public constant PALMTerms =
        0xB041f628e961598af9874BCf30CC865f67fad3EE;
    address public constant GELOwner =
        0x8bEC285f1d4527f28F69ed18144be74f091B9aF9;
    address public constant GELPool =
        0x2dd31cc03Ed996A99Fbfdffa07f8f4604B1a2eC1;

    // #endregion arrakis v2 contract.

    // #region gnosis safe.

    address public constant gnosisSafeProxyFactory =
        0xa6B71E26C5e0845f74c812102Ca7114b6a896AB2;
    address public constant gnosisSafe =
        0xd9Db270c1B5E3Bd161E8c8503c55cEABeE709552;
    address public constant fallbackHandler =
        0xf48f2B2d2a534e402487b3ee7C18c33Aec0Fe5e4;

    // #endregion gnosis safe.

    // #region uniswap contracts.

    address public constant permit2 =
        0x000000000022D473030F116dDEE9F6B43aC78BA3;

    // #endregion uniswap contracts.

    address public owner;
    address public owner0;
    address public owner1;

    /// @dev should be used as a private module.
    address public uniswapStandardModuleImplementation;
    address public uniswapStandardModuleBeacon;

    address public privateModule;
    address public vault;
    address public executor;
    address public stratAnnouncer;

    // #region arrakis.

    address public router;
    address public swapExecutor;
    address public uniV4resolver;

    // #endregion arrakis.

    // #region uniswap v4.

    address public poolManager;

    // #endregion uniswap v4.

    // #region mocks.

    address public oracle;

    // #endregion mocks.

    // #region vault infos.

    uint256 public init0;
    uint256 public init1;
    uint24 public maxSlippage;
    PoolKey public poolKey;
    uint160 public sqrtPriceX96;

    // #endregion vault infos.

    IERC20Metadata public token0;
    IERC20Metadata public token1;

    // #region withdrawal helper safe module.

    WithdrawHelper public withdrawHelper;
    MigrationHelper public migrationHelper;

    // #endregion withdrawal helper safe module.

    function setUp() public {
        // #region reset fork.

        _reset(vm.envString("ETH_RPC_URL"), 21_823_411);

        // #endregion reset fork.

        // #region setup.

        owner0 = vm.addr(10);
        owner1 = vm.addr(11);
        owner = vm.addr(uint256(keccak256(abi.encode("Owner"))));
        executor = vm.addr(uint256(keccak256(abi.encode("Executor"))));
        stratAnnouncer =
            vm.addr(uint256(keccak256(abi.encode("StratAnnouncer"))));

        (token0, token1) =
            (IERC20Metadata(USDC), IERC20Metadata(WETH));

        // #region create an oracle.

        oracle = address(new OracleWrapper());

        // #endregion create an oracle.

        _setup();

        // #endregion setup.

        // #region create an uniswap v4 pool.

        Currency currency0 = Currency.wrap(USDC);
        Currency currency1 = Currency.wrap(WETH);

        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 10_000,
            tickSpacing: 10,
            hooks: IHooks(address(0))
        });

        sqrtPriceX96 = 1_356_476_084_642_877_807_665_053_548_195_417;

        IPoolManager(poolManager).unlock(abi.encode(0));

        // #endregion create an uniswap v4 pool.

        // #region create withdrawal helper safe module.

        withdrawHelper = new WithdrawHelper();

        // #endregion create withdrawal helper safe module.
    }

    // #region uniswap v4 callback function.

    function unlockCallback(
        bytes calldata data
    ) public returns (bytes memory) {
        uint256 typeOfLockAcquired = abi.decode(data, (uint256));

        if (typeOfLockAcquired == 0) {
            IPoolManager(poolManager).initialize(
                poolKey, sqrtPriceX96
            );
        }
    }

    // #endregion uniswap v4 callback function.

    // #region withdraw module.

    function test_withdraw_through_safe_module() public {
        // #region create a safe.

        address[] memory owners = new address[](2);
        owners[0] = owner0;
        owners[1] = owner1;

        bytes memory payload = abi.encodeWithSelector(
            IGnosisSafe.setup.selector,
            owners,
            1,
            address(0),
            "",
            fallbackHandler,
            address(0),
            0,
            payable(address(0))
        );

        address safe = address(
            IGnosisSafeProxyFactory(gnosisSafeProxyFactory)
                .createProxy(gnosisSafe, payload)
        );

        // #endregion create a safe.

        // #region create a vault.

        bytes32 salt =
            keccak256(abi.encode("Private vault Univ4 salt"));
        init0 = 1;
        init1 = 0;
        maxSlippage = 10_000;

        bytes memory moduleCreationPayload = abi.encodeWithSelector(
            IUniV4StandardModule.initialize.selector,
            init0,
            init1,
            false,
            poolKey,
            IOracleWrapper(oracle),
            maxSlippage
        );

        bytes memory initManagementPayload = abi.encode(
            IOracleWrapper(oracle),
            TEN_PERCENT,
            uint256(60),
            executor,
            stratAnnouncer,
            maxSlippage
        );

        vault = IArrakisMetaVaultFactory(factory).deployPrivateVault(
            salt,
            USDC,
            WETH,
            safe,
            uniswapStandardModuleBeacon,
            moduleCreationPayload,
            initManagementPayload
        );

        privateModule = address(IArrakisMetaVault(vault).module());

        // #endregion create a vault.

        // #region whitelist safe as depositor.

        bytes memory signatures;

        {
            address[] memory depositors = new address[](2);
            depositors[1] = safe;
            depositors[0] = owner0;

            uint256 nonce = IGnosisSafe(safe).nonce();

            bytes32 txHash = IGnosisSafe(safe).getTransactionHash(
                vault,
                0,
                abi.encodeWithSelector(
                    IArrakisMetaVaultPrivate
                        .whitelistDepositors
                        .selector,
                    depositors
                ),
                Operation.Call,
                0,
                0,
                0,
                address(0),
                address(0),
                nonce
            );

            // #region create a signature.

            signatures = _getSignature(txHash);

            vm.prank(owner0);
            IGnosisSafe(safe).execTransaction(
                vault,
                0,
                abi.encodeWithSelector(
                    IArrakisMetaVaultPrivate
                        .whitelistDepositors
                        .selector,
                    depositors
                ),
                Operation.Call,
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                signatures
            );

            // #endregion create a signature.

            depositors = IArrakisMetaVaultPrivate(vault).depositors();
        }

        // #endregion whitelist safe as depositor.

        // #region deposit into the vault.

        {
            bytes memory payload;

            {
                uint256 amount0 = 3000e6;
                uint256 amount1 = 1e18;

                deal(USDC, safe, amount0);
                deal(WETH, safe, amount1);

                vm.startPrank(safe);
                IERC20Metadata(USDC).approve(privateModule, amount0);
                IERC20Metadata(WETH).approve(privateModule, amount1);
                vm.stopPrank();

                payload = abi.encodeWithSelector(
                    IArrakisMetaVaultPrivate.deposit.selector,
                    amount0,
                    amount1
                );
            }

            uint256 nonce = IGnosisSafe(safe).nonce();

            bytes32 txHash = IGnosisSafe(safe).getTransactionHash(
                vault,
                0,
                payload,
                Operation.Call,
                0,
                0,
                0,
                address(0),
                address(0),
                nonce
            );

            signatures = _getSignature(txHash);

            vm.prank(owner0);
            IGnosisSafe(safe).execTransaction(
                vault,
                0,
                payload,
                Operation.Call,
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                signatures
            );
        }

        // #endregion deposit into the vault.

        // #region whitelist withdrawal module.

        {
            bytes memory payload = abi.encodeWithSelector(
                IGnosisSafe.enableModule.selector,
                address(withdrawHelper)
            );

            uint256 nonce = IGnosisSafe(safe).nonce();

            bytes32 txHash = IGnosisSafe(safe).getTransactionHash(
                safe,
                0,
                payload,
                Operation.Call,
                0,
                0,
                0,
                address(0),
                address(0),
                nonce
            );

            signatures = _getSignature(txHash);

            vm.prank(owner1);
            IGnosisSafe(safe).execTransaction(
                safe,
                0,
                payload,
                Operation.Call,
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                signatures
            );
        }

        // #endregion whitelist withdrawal module.

        // #region do withdraw throught the module.

        {
            bytes memory payload;
            {
                uint256 amount0 = 1500e6;
                uint256 amount1 = 0;

                payload = abi.encodeWithSelector(
                    WithdrawHelper.withdraw.selector,
                    safe,
                    vault,
                    amount0,
                    amount1,
                    safe
                );
            }

            uint256 nonce = IGnosisSafe(safe).nonce();

            bytes32 txHash = IGnosisSafe(safe).getTransactionHash(
                address(withdrawHelper),
                0,
                payload,
                Operation.Call,
                0,
                0,
                0,
                address(0),
                address(0),
                nonce
            );

            signatures = _getSignature(txHash);

            assertEq(IERC20Metadata(USDC).balanceOf(safe), 0);

            vm.prank(owner1);
            IGnosisSafe(safe).execTransaction(
                address(withdrawHelper),
                0,
                payload,
                Operation.Call,
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                signatures
            );

            assertEq(IERC20Metadata(USDC).balanceOf(safe), 1500e6);
        }

        // #endregion do withdraw throught the module.
    }

    function test_withdraw_through_safe_module_case_2() public {
        // #region create a safe.

        address[] memory owners = new address[](2);
        owners[0] = owner0;
        owners[1] = owner1;

        bytes memory payload = abi.encodeWithSelector(
            IGnosisSafe.setup.selector,
            owners,
            1,
            address(0),
            "",
            fallbackHandler,
            address(0),
            0,
            payable(address(0))
        );

        address safe = address(
            IGnosisSafeProxyFactory(gnosisSafeProxyFactory)
                .createProxy(gnosisSafe, payload)
        );

        // #endregion create a safe.

        // #region create a vault.

        bytes32 salt =
            keccak256(abi.encode("Private vault Univ4 salt"));
        init0 = 1;
        init1 = 0;
        maxSlippage = 10_000;

        bytes memory moduleCreationPayload = abi.encodeWithSelector(
            IUniV4StandardModule.initialize.selector,
            init0,
            init1,
            false,
            poolKey,
            IOracleWrapper(oracle),
            maxSlippage
        );

        bytes memory initManagementPayload = abi.encode(
            IOracleWrapper(oracle),
            TEN_PERCENT,
            uint256(60),
            executor,
            stratAnnouncer,
            maxSlippage
        );

        vault = IArrakisMetaVaultFactory(factory).deployPrivateVault(
            salt,
            USDC,
            WETH,
            safe,
            uniswapStandardModuleBeacon,
            moduleCreationPayload,
            initManagementPayload
        );

        privateModule = address(IArrakisMetaVault(vault).module());

        // #endregion create a vault.

        // #region whitelist safe as depositor.

        bytes memory signatures;

        {
            address[] memory depositors = new address[](1);
            depositors[0] = owner0;

            uint256 nonce = IGnosisSafe(safe).nonce();

            bytes32 txHash = IGnosisSafe(safe).getTransactionHash(
                vault,
                0,
                abi.encodeWithSelector(
                    IArrakisMetaVaultPrivate
                        .whitelistDepositors
                        .selector,
                    depositors
                ),
                Operation.Call,
                0,
                0,
                0,
                address(0),
                address(0),
                nonce
            );

            // #region create a signature.

            signatures = _getSignature(txHash);

            vm.prank(owner0);
            IGnosisSafe(safe).execTransaction(
                vault,
                0,
                abi.encodeWithSelector(
                    IArrakisMetaVaultPrivate
                        .whitelistDepositors
                        .selector,
                    depositors
                ),
                Operation.Call,
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                signatures
            );

            // #endregion create a signature.

            depositors = IArrakisMetaVaultPrivate(vault).depositors();
        }

        // #endregion whitelist safe as depositor.

        // #region deposit into the vault.

        {
            uint256 amount0 = 3000e6;
            uint256 amount1 = 1e18;

            deal(USDC, owner0, amount0);
            deal(WETH, owner0, amount1);

            vm.startPrank(owner0);
            IERC20Metadata(USDC).approve(privateModule, amount0);
            IERC20Metadata(WETH).approve(privateModule, amount1);
            IArrakisMetaVaultPrivate(vault).deposit(amount0, amount1);
            vm.stopPrank();
        }

        // #endregion deposit into the vault.

        // #region whitelist withdrawal module.

        {
            bytes memory payload = abi.encodeWithSelector(
                IGnosisSafe.enableModule.selector,
                address(withdrawHelper)
            );

            uint256 nonce = IGnosisSafe(safe).nonce();

            bytes32 txHash = IGnosisSafe(safe).getTransactionHash(
                safe,
                0,
                payload,
                Operation.Call,
                0,
                0,
                0,
                address(0),
                address(0),
                nonce
            );

            signatures = _getSignature(txHash);

            vm.prank(owner1);
            IGnosisSafe(safe).execTransaction(
                safe,
                0,
                payload,
                Operation.Call,
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                signatures
            );
        }

        // #endregion whitelist withdrawal module.

        // #region do withdraw throught the module.

        {
            bytes memory payload;
            {
                uint256 amount0 = 0;
                uint256 amount1 = 1e17;

                payload = abi.encodeWithSelector(
                    WithdrawHelper.withdraw.selector,
                    safe,
                    vault,
                    amount0,
                    amount1,
                    safe
                );
            }

            uint256 nonce = IGnosisSafe(safe).nonce();

            bytes32 txHash = IGnosisSafe(safe).getTransactionHash(
                address(withdrawHelper),
                0,
                payload,
                Operation.Call,
                0,
                0,
                0,
                address(0),
                address(0),
                nonce
            );

            signatures = _getSignature(txHash);

            assertEq(IERC20Metadata(WETH).balanceOf(safe), 0);

            vm.prank(owner1);
            IGnosisSafe(safe).execTransaction(
                address(withdrawHelper),
                0,
                payload,
                Operation.Call,
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                signatures
            );

            assertEq(IERC20Metadata(WETH).balanceOf(safe), 1e17);
        }

        // #endregion do withdraw throught the module.
    }

    function test_withdraw_through_safe_module_case_3() public {
        // #region create a safe.

        address[] memory owners = new address[](2);
        owners[0] = owner0;
        owners[1] = owner1;

        bytes memory payload = abi.encodeWithSelector(
            IGnosisSafe.setup.selector,
            owners,
            1,
            address(0),
            "",
            fallbackHandler,
            address(0),
            0,
            payable(address(0))
        );

        address safe = address(
            IGnosisSafeProxyFactory(gnosisSafeProxyFactory)
                .createProxy(gnosisSafe, payload)
        );

        // #endregion create a safe.

        // #region create a vault.

        bytes32 salt =
            keccak256(abi.encode("Private vault Univ4 salt"));
        init0 = 1;
        init1 = 0;
        maxSlippage = 10_000;

        bytes memory moduleCreationPayload = abi.encodeWithSelector(
            IUniV4StandardModule.initialize.selector,
            init0,
            init1,
            false,
            poolKey,
            IOracleWrapper(oracle),
            maxSlippage
        );

        bytes memory initManagementPayload = abi.encode(
            IOracleWrapper(oracle),
            TEN_PERCENT,
            uint256(60),
            executor,
            stratAnnouncer,
            maxSlippage
        );

        vault = IArrakisMetaVaultFactory(factory).deployPrivateVault(
            salt,
            USDC,
            WETH,
            safe,
            uniswapStandardModuleBeacon,
            moduleCreationPayload,
            initManagementPayload
        );

        privateModule = address(IArrakisMetaVault(vault).module());

        // #endregion create a vault.

        // #region whitelist safe as depositor.

        bytes memory signatures;

        {
            address[] memory depositors = new address[](1);
            depositors[0] = owner0;

            uint256 nonce = IGnosisSafe(safe).nonce();

            bytes32 txHash = IGnosisSafe(safe).getTransactionHash(
                vault,
                0,
                abi.encodeWithSelector(
                    IArrakisMetaVaultPrivate
                        .whitelistDepositors
                        .selector,
                    depositors
                ),
                Operation.Call,
                0,
                0,
                0,
                address(0),
                address(0),
                nonce
            );

            // #region create a signature.

            signatures = _getSignature(txHash);

            vm.prank(owner0);
            IGnosisSafe(safe).execTransaction(
                vault,
                0,
                abi.encodeWithSelector(
                    IArrakisMetaVaultPrivate
                        .whitelistDepositors
                        .selector,
                    depositors
                ),
                Operation.Call,
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                signatures
            );

            // #endregion create a signature.

            depositors = IArrakisMetaVaultPrivate(vault).depositors();
        }

        // #endregion whitelist safe as depositor.

        // #region deposit into the vault.

        {
            uint256 amount0 = 3000e6;
            uint256 amount1 = 1e18;

            deal(USDC, owner0, amount0);
            deal(WETH, owner0, amount1);

            vm.startPrank(owner0);
            IERC20Metadata(USDC).approve(privateModule, amount0);
            IERC20Metadata(WETH).approve(privateModule, amount1);
            IArrakisMetaVaultPrivate(vault).deposit(amount0, amount1);
            vm.stopPrank();
        }

        // #endregion deposit into the vault.

        // #region whitelist withdrawal module.

        {
            bytes memory payload = abi.encodeWithSelector(
                IGnosisSafe.enableModule.selector,
                address(withdrawHelper)
            );

            uint256 nonce = IGnosisSafe(safe).nonce();

            bytes32 txHash = IGnosisSafe(safe).getTransactionHash(
                safe,
                0,
                payload,
                Operation.Call,
                0,
                0,
                0,
                address(0),
                address(0),
                nonce
            );

            signatures = _getSignature(txHash);

            vm.prank(owner1);
            IGnosisSafe(safe).execTransaction(
                safe,
                0,
                payload,
                Operation.Call,
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                signatures
            );
        }

        // #endregion whitelist withdrawal module.

        // #region do withdraw throught the module.

        {
            uint256 amount0 = 0;
            uint256 amount1 = 1e17;

            address notOwner =
                vm.addr(uint256(keccak256(abi.encode("NotOwner"))));

            vm.prank(notOwner);
            vm.expectRevert(IWithdrawHelper.Unauthorized.selector);
            IWithdrawHelper(withdrawHelper).withdraw(
                safe, vault, amount0, amount1, payable(safe)
            );
        }

        // #endregion do withdraw throught the module.
    }

    function test_withdraw_through_safe_module_case_4() public {
        // #region create a safe.

        address[] memory owners = new address[](2);
        owners[0] = owner0;
        owners[1] = owner1;

        bytes memory payload = abi.encodeWithSelector(
            IGnosisSafe.setup.selector,
            owners,
            1,
            address(0),
            "",
            fallbackHandler,
            address(0),
            0,
            payable(address(0))
        );

        address safe = address(
            IGnosisSafeProxyFactory(gnosisSafeProxyFactory)
                .createProxy(gnosisSafe, payload)
        );

        // #endregion create a safe.

        // #region create a vault.

        bytes32 salt =
            keccak256(abi.encode("Private vault Univ4 salt"));
        init0 = 1;
        init1 = 0;
        maxSlippage = 10_000;

        bytes memory moduleCreationPayload = abi.encodeWithSelector(
            IUniV4StandardModule.initialize.selector,
            init0,
            init1,
            false,
            poolKey,
            IOracleWrapper(oracle),
            maxSlippage
        );

        bytes memory initManagementPayload = abi.encode(
            IOracleWrapper(oracle),
            TEN_PERCENT,
            uint256(60),
            executor,
            stratAnnouncer,
            maxSlippage
        );

        vault = IArrakisMetaVaultFactory(factory).deployPrivateVault(
            salt,
            USDC,
            WETH,
            safe,
            uniswapStandardModuleBeacon,
            moduleCreationPayload,
            initManagementPayload
        );

        privateModule = address(IArrakisMetaVault(vault).module());

        // #endregion create a vault.

        // #region whitelist safe as depositor.

        bytes memory signatures;

        {
            address[] memory depositors = new address[](1);
            depositors[0] = owner0;

            uint256 nonce = IGnosisSafe(safe).nonce();

            bytes32 txHash = IGnosisSafe(safe).getTransactionHash(
                vault,
                0,
                abi.encodeWithSelector(
                    IArrakisMetaVaultPrivate
                        .whitelistDepositors
                        .selector,
                    depositors
                ),
                Operation.Call,
                0,
                0,
                0,
                address(0),
                address(0),
                nonce
            );

            // #region create a signature.

            signatures = _getSignature(txHash);

            vm.prank(owner0);
            IGnosisSafe(safe).execTransaction(
                vault,
                0,
                abi.encodeWithSelector(
                    IArrakisMetaVaultPrivate
                        .whitelistDepositors
                        .selector,
                    depositors
                ),
                Operation.Call,
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                signatures
            );

            // #endregion create a signature.

            depositors = IArrakisMetaVaultPrivate(vault).depositors();
        }

        // #endregion whitelist safe as depositor.

        // #region deposit into the vault.

        {
            uint256 amount0 = 3000e6;
            uint256 amount1 = 1e18;

            deal(USDC, owner0, amount0);
            deal(WETH, owner0, amount1);

            vm.startPrank(owner0);
            IERC20Metadata(USDC).approve(privateModule, amount0);
            IERC20Metadata(WETH).approve(privateModule, amount1);
            IArrakisMetaVaultPrivate(vault).deposit(amount0, amount1);
            vm.stopPrank();
        }

        // #endregion deposit into the vault.

        // #region whitelist withdrawal module.

        {
            bytes memory payload = abi.encodeWithSelector(
                IGnosisSafe.enableModule.selector,
                address(withdrawHelper)
            );

            uint256 nonce = IGnosisSafe(safe).nonce();

            bytes32 txHash = IGnosisSafe(safe).getTransactionHash(
                safe,
                0,
                payload,
                Operation.Call,
                0,
                0,
                0,
                address(0),
                address(0),
                nonce
            );

            signatures = _getSignature(txHash);

            vm.prank(owner1);
            IGnosisSafe(safe).execTransaction(
                safe,
                0,
                payload,
                Operation.Call,
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                signatures
            );
        }

        // #endregion whitelist withdrawal module.

        // #region do withdraw throught the module.

        {
            bytes memory payload;
            {
                uint256 amount0 = 0;
                uint256 amount1 = type(uint256).max;

                payload = abi.encodeWithSelector(
                    WithdrawHelper.withdraw.selector,
                    safe,
                    vault,
                    amount0,
                    amount1,
                    safe
                );
            }

            uint256 nonce = IGnosisSafe(safe).nonce();

            bytes32 txHash = IGnosisSafe(safe).getTransactionHash(
                address(withdrawHelper),
                0,
                payload,
                Operation.Call,
                0,
                0,
                0,
                address(0),
                address(0),
                nonce
            );

            signatures = _getSignature(txHash);

            vm.prank(owner1);
            vm.expectRevert("GS013"); // InsufficientUnderlying error reverting behind.
            IGnosisSafe(safe).execTransaction(
                address(withdrawHelper),
                0,
                payload,
                Operation.Call,
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                signatures
            );
        }

        // #endregion do withdraw throught the module.
    }

    // #endregion withdraw module.

    // #region migration module.

    // #region test migration module constructor.

    function test_constructor_palmTerms_address_zero() public {
        vm.expectRevert(IMigrationHelper.AddressZero.selector);
        migrationHelper = new MigrationHelper(
            address(0),
            factory,
            arrakisStandardManager,
            poolManager,
            WETH,
            arrakisTimeLock
        );
    }

    function test_constructor_factory_address_zero() public {
        vm.expectRevert(IMigrationHelper.AddressZero.selector);
        migrationHelper = new MigrationHelper(
            PALMTerms,
            address(0),
            arrakisStandardManager,
            poolManager,
            WETH,
            arrakisTimeLock
        );
    }

    function test_constructor_arrakisStandardManager_address_zero()
        public
    {
        vm.expectRevert(IMigrationHelper.AddressZero.selector);
        migrationHelper = new MigrationHelper(
            PALMTerms,
            factory,
            address(0),
            poolManager,
            WETH,
            arrakisTimeLock
        );
    }

    function test_constructor_poolManager_address_zero() public {
        vm.expectRevert(IMigrationHelper.AddressZero.selector);
        migrationHelper = new MigrationHelper(
            PALMTerms,
            factory,
            arrakisStandardManager,
            address(0),
            WETH,
            arrakisTimeLock
        );
    }

    function test_constructor_weth_address_zero() public {
        vm.expectRevert(IMigrationHelper.AddressZero.selector);
        migrationHelper = new MigrationHelper(
            PALMTerms,
            factory,
            arrakisStandardManager,
            poolManager,
            address(0),
            arrakisTimeLock
        );
    }

    function test_constructor_owner_address_zero() public {
        vm.expectRevert(IMigrationHelper.AddressZero.selector);
        migrationHelper = new MigrationHelper(
            PALMTerms,
            factory,
            arrakisStandardManager,
            poolManager,
            WETH,
            address(0)
        );
    }

    // #region test migration.

    function test_migration_closeTermsErr() public {
        // #region create migration helper.

        migrationHelper = new MigrationHelper(
            PALMTerms,
            factory,
            arrakisStandardManager,
            poolManager,
            WETH,
            arrakisTimeLock
        );

        // #endregion create migration helper.

        OracleWrapper oracleWrapper = new OracleWrapper();

        // #region create a GEL pool on uniswap v4.

        address token0 = address(IArrakisV2(GELV2Vault).token0());
        address token1 = address(IArrakisV2(GELV2Vault).token1());

        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 10_000,
            tickSpacing: 200,
            hooks: IHooks(address(0))
        });

        (uint160 sqrtPrice,,,,,,) =
            IUniswapV3PoolState(GELPool).slot0();

        int24 tick =
            IPoolManager(poolManager).initialize(poolKey, sqrtPrice);

        console.logInt(tick);

        // #endregion create a GEL pool on uniswap v4.

        // #region migration payload.

        IMigrationHelper.Migration memory migration;

        migration.safe = GELOwner;
        migration.closeTerm.vault = IArrakisV2(GELV2Vault);
        migration.closeTerm.newOwner = address(0);
        migration.closeTerm.newManager =
            vm.addr(uint256(keccak256(abi.encode("NewManager"))));

        migration.poolCreation.poolKey = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 10_000,
            tickSpacing: 200,
            hooks: IHooks(address(0))
        });

        migration.poolCreation.sqrtPriceX96 = 0;

        migration.vaultCreation.salt =
            keccak256(abi.encode("Migration salt"));
        migration.vaultCreation.upgradeableBeacon =
            uniswapStandardModuleBeacon;
        migration.vaultCreation.init0 = 1;
        migration.vaultCreation.init1 = 1;
        // migration.vaultCreation.moduleCreationPayload = abi
        //     .encodeWithSelector(
        //     IUniV4StandardModule.initialize.selector,
        //     1,
        //     1,
        //     false,
        //     poolKey,
        //     IOracleWrapper(address(oracleWrapper)),
        //     PIPS / 50
        // );

        migration.vaultCreation.oracle =
            IOracleWrapper(address(oracleWrapper));
        migration.vaultCreation.maxDeviation = PIPS / 50;
        migration.vaultCreation.cooldownPeriod = 60;
        migration.vaultCreation.stratAnnouncer =
            vm.addr(uint256(keccak256(abi.encode("StratAnnouncer"))));
        migration.vaultCreation.maxSlippage = PIPS / 50;

        migration.executor =
            vm.addr(uint256(keccak256(abi.encode("Executor"))));

        // #endregion migration payload.

        // #region whitelist migration module.

        vm.prank(GELOwner);
        IGnosisSafe(GELOwner).enableModule(address(migrationHelper));

        // #endregion whitelist migration module.

        // #region do migration.

        vm.prank(arrakisTimeLock);
        vm.expectRevert(IMigrationHelper.CloseTermsErr.selector);
        migrationHelper.migrateVault(migration);

        // #endregion do migration.
    }

    function test_migration_with_pool_creation() public {
        // #region create migration helper.

        migrationHelper = new MigrationHelper(
            PALMTerms,
            factory,
            arrakisStandardManager,
            poolManager,
            WETH,
            arrakisTimeLock
        );

        // #endregion create migration helper.

        OracleWrapper oracleWrapper = new OracleWrapper();

        // #region create a GEL pool on uniswap v4.

        address token0 = address(IArrakisV2(GELV2Vault).token0());
        address token1 = address(IArrakisV2(GELV2Vault).token1());

        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 10_000,
            tickSpacing: 200,
            hooks: IHooks(address(0))
        });

        (uint160 sqrtPrice,,,,,,) =
            IUniswapV3PoolState(GELPool).slot0();

        int24 tick =
            IPoolManager(poolManager).initialize(poolKey, sqrtPrice);

        console.logInt(tick);

        // #endregion create a GEL pool on uniswap v4.

        // #region migration payload.

        IMigrationHelper.Migration memory migration;

        migration.safe = GELOwner;
        migration.closeTerm.vault = IArrakisV2(GELV2Vault);
        migration.closeTerm.newOwner =
            vm.addr(uint256(keccak256(abi.encode("NewOwner"))));
        migration.closeTerm.newManager =
            vm.addr(uint256(keccak256(abi.encode("NewManager"))));

        migration.poolCreation.poolKey = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 10_001,
            tickSpacing: 200,
            hooks: IHooks(address(0))
        });

        migration.poolCreation.sqrtPriceX96 = sqrtPrice;

        migration.vaultCreation.salt =
            keccak256(abi.encode("Migration salt"));
        migration.vaultCreation.upgradeableBeacon =
            uniswapStandardModuleBeacon;
        migration.vaultCreation.init0 = 1;
        migration.vaultCreation.init1 = 1;
        // migration.vaultCreation.moduleCreationPayload = abi
        //     .encodeWithSelector(
        //     IUniV4StandardModule.initialize.selector,
        //     1,
        //     1,
        //     false,
        //     poolKey,
        //     IOracleWrapper(address(oracleWrapper)),
        //     PIPS / 50
        // );

        migration.vaultCreation.oracle =
            IOracleWrapper(address(oracleWrapper));
        migration.vaultCreation.maxDeviation = PIPS / 50;
        migration.vaultCreation.cooldownPeriod = 60;
        migration.vaultCreation.stratAnnouncer =
            vm.addr(uint256(keccak256(abi.encode("StratAnnouncer"))));
        migration.vaultCreation.maxSlippage = PIPS / 50;

        migration.executor =
            vm.addr(uint256(keccak256(abi.encode("Executor"))));

        // #endregion migration payload.

        // #region whitelist migration module.

        vm.prank(GELOwner);
        IGnosisSafe(GELOwner).enableModule(address(migrationHelper));

        // #endregion whitelist migration module.

        // #region do migration.

        vm.prank(arrakisTimeLock);
        migrationHelper.migrateVault(migration);

        // #endregion do migration.
    }

    function test_migration_conversion_to_eth_vault() public {
        // #region create migration helper.

        migrationHelper = new MigrationHelper(
            PALMTerms,
            factory,
            arrakisStandardManager,
            poolManager,
            WETH,
            arrakisTimeLock
        );

        // #endregion create migration helper.

        OracleWrapper oracleWrapper = new OracleWrapper();

        // #region create a GEL pool on uniswap v4.

        address token0 = address(IArrakisV2(GELV2Vault).token0());
        address token1 = address(IArrakisV2(GELV2Vault).token1());

        PoolKey memory poolKey = PoolKey({
            currency0: CurrencyLibrary.ADDRESS_ZERO,
            currency1: Currency.wrap(token0),
            fee: 10_000,
            tickSpacing: 200,
            hooks: IHooks(address(0))
        });

        (uint160 sqrtPrice,,,,,,) =
            IUniswapV3PoolState(GELPool).slot0();

        // int24 tick =
        //     IPoolManager(poolManager).initialize(poolKey, sqrtPrice);

        // console.logInt(tick);

        // #endregion create a GEL pool on uniswap v4.

        // #region migration payload.

        IMigrationHelper.Migration memory migration;

        migration.safe = GELOwner;
        migration.closeTerm.vault = IArrakisV2(GELV2Vault);
        migration.closeTerm.newOwner =
            vm.addr(uint256(keccak256(abi.encode("NewOwner"))));
        migration.closeTerm.newManager =
            vm.addr(uint256(keccak256(abi.encode("NewManager"))));

        migration.poolCreation.poolKey = poolKey;

        migration.poolCreation.sqrtPriceX96 = sqrtPrice;

        migration.vaultCreation.salt =
            keccak256(abi.encode("Migration salt"));
        migration.vaultCreation.upgradeableBeacon =
            uniswapStandardModuleBeacon;
        migration.vaultCreation.init0 = 1;
        migration.vaultCreation.init1 = 1;
        // migration.vaultCreation.moduleCreationPayload = abi
        //     .encodeWithSelector(
        //     IUniV4StandardModule.initialize.selector,
        //     1,
        //     1,
        //     false,
        //     poolKey,
        //     IOracleWrapper(address(oracleWrapper)),
        //     PIPS / 50
        // );

        migration.vaultCreation.oracle =
            IOracleWrapper(address(oracleWrapper));
        migration.vaultCreation.maxDeviation = PIPS / 50;
        migration.vaultCreation.cooldownPeriod = 60;
        migration.vaultCreation.stratAnnouncer =
            vm.addr(uint256(keccak256(abi.encode("StratAnnouncer"))));
        migration.vaultCreation.maxSlippage = PIPS / 50;

        migration.executor =
            vm.addr(uint256(keccak256(abi.encode("Executor"))));

        // #endregion migration payload.

        // #region whitelist migration module.

        vm.prank(GELOwner);
        IGnosisSafe(GELOwner).enableModule(address(migrationHelper));

        // #endregion whitelist migration module.

        // #region do migration.

        vm.prank(arrakisTimeLock);
        migrationHelper.migrateVault(migration);

        // #endregion do migration.
    }

    function test_migration_conversion_to_eth_vault_rebalance() public {
        // #region create migration helper.

        migrationHelper = new MigrationHelper(
            PALMTerms,
            factory,
            arrakisStandardManager,
            poolManager,
            WETH,
            arrakisTimeLock
        );

        // #endregion create migration helper.

        OracleWrapper oracleWrapper = new OracleWrapper();

        // #region create a GEL pool on uniswap v4.

        address token0 = address(IArrakisV2(GELV2Vault).token0());
        address token1 = address(IArrakisV2(GELV2Vault).token1());

        PoolKey memory poolKey = PoolKey({
            currency0: CurrencyLibrary.ADDRESS_ZERO,
            currency1: Currency.wrap(token0),
            fee: 10_000,
            tickSpacing: 200,
            hooks: IHooks(address(0))
        });

        (uint160 sqrtPrice,,,,,,) =
            IUniswapV3PoolState(GELPool).slot0();

        oracleWrapper.setPrice1(
            FullMath.mulDiv(
                uint256(sqrtPrice) * uint256(sqrtPrice),
                10 ** 18,
                1 << 192
            )
        );

        // int24 tick =
        //     IPoolManager(poolManager).initialize(poolKey, sqrtPrice);

        // console.logInt(tick);

        // #endregion create a GEL pool on uniswap v4.

        // #region migration payload.

        IMigrationHelper.Migration memory migration;

        migration.safe = GELOwner;
        migration.closeTerm.vault = IArrakisV2(GELV2Vault);
        migration.closeTerm.newOwner =
            vm.addr(uint256(keccak256(abi.encode("NewOwner"))));
        migration.closeTerm.newManager =
            vm.addr(uint256(keccak256(abi.encode("NewManager"))));

        migration.poolCreation.poolKey = poolKey;

        migration.poolCreation.sqrtPriceX96 = sqrtPrice;

        migration.vaultCreation.salt =
            keccak256(abi.encode("Migration salt"));
        migration.vaultCreation.upgradeableBeacon =
            uniswapStandardModuleBeacon;
        migration.vaultCreation.init0 = 1;
        migration.vaultCreation.init1 = 1;
        // migration.vaultCreation.moduleCreationPayload = abi
        //     .encodeWithSelector(
        //     IUniV4StandardModule.initialize.selector,
        //     1,
        //     1,
        //     false,
        //     poolKey,
        //     IOracleWrapper(address(oracleWrapper)),
        //     PIPS / 50
        // );

        migration.vaultCreation.oracle =
            IOracleWrapper(address(oracleWrapper));
        migration.vaultCreation.maxDeviation = PIPS / 50;
        migration.vaultCreation.cooldownPeriod = 60;
        migration.vaultCreation.stratAnnouncer =
            vm.addr(uint256(keccak256(abi.encode("StratAnnouncer"))));
        migration.vaultCreation.maxSlippage = PIPS / 50;

        migration.executor =
            vm.addr(uint256(keccak256(abi.encode("Executor"))));

        IUniV4StandardModule.LiquidityRange[] memory ranges = new IUniV4StandardModule.LiquidityRange[](0);
        // ranges[0] = IUniV4StandardModule.LiquidityRange({
        //     range : IUniV4StandardModule.Range({
        //         tickLower : TickMath.MIN_TICK / 2,
        //         tickUpper : TickMath.MAX_TICK / 2
        //     }),
        //     liquidity : 0
        // });

        SwapPayload memory swapPayload;

        migration.rebalancePayloads = new bytes[](1);
        migration.rebalancePayloads[0] = abi.encodeWithSelector(
            IUniV4StandardModule.rebalance.selector,
            ranges,
            swapPayload,
            0,
            0,
            0,
            0
        );

        // #endregion migration payload.

        // #region whitelist migration module.

        vm.prank(GELOwner);
        IGnosisSafe(GELOwner).enableModule(address(migrationHelper));

        // #endregion whitelist migration module.

        // #region do migration.

        vm.prank(arrakisTimeLock);
        migrationHelper.migrateVault(migration);

        // #endregion do migration.
    }

    // #endregion test migration.

    function test_migration_module() public {
        // #region create migration helper.

        migrationHelper = new MigrationHelper(
            PALMTerms,
            factory,
            arrakisStandardManager,
            poolManager,
            WETH,
            arrakisTimeLock
        );

        // #endregion create migration helper.

        OracleWrapper oracleWrapper = new OracleWrapper();

        // #region create a GEL pool on uniswap v4.

        address token0 = address(IArrakisV2(GELV2Vault).token0());
        address token1 = address(IArrakisV2(GELV2Vault).token1());

        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 10_000,
            tickSpacing: 200,
            hooks: IHooks(address(0))
        });

        (uint160 sqrtPrice,,,,,,) =
            IUniswapV3PoolState(GELPool).slot0();

        int24 tick =
            IPoolManager(poolManager).initialize(poolKey, sqrtPrice);

        console.logInt(tick);

        // #endregion create a GEL pool on uniswap v4.

        // #region migration payload.

        IMigrationHelper.Migration memory migration;

        migration.safe = GELOwner;
        migration.closeTerm.vault = IArrakisV2(GELV2Vault);
        migration.closeTerm.newOwner =
            vm.addr(uint256(keccak256(abi.encode("NewOwner"))));
        migration.closeTerm.newManager =
            vm.addr(uint256(keccak256(abi.encode("NewManager"))));

        migration.poolCreation.poolKey = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 10_000,
            tickSpacing: 200,
            hooks: IHooks(address(0))
        });

        migration.poolCreation.sqrtPriceX96 = 0;

        migration.vaultCreation.salt =
            keccak256(abi.encode("Migration salt"));
        migration.vaultCreation.upgradeableBeacon =
            uniswapStandardModuleBeacon;
        migration.vaultCreation.init0 = 1;
        migration.vaultCreation.init1 = 1;
        // migration.vaultCreation.moduleCreationPayload = abi
        //     .encodeWithSelector(
        //     IUniV4StandardModule.initialize.selector,
        //     1,
        //     1,
        //     false,
        //     poolKey,
        //     IOracleWrapper(address(oracleWrapper)),
        //     PIPS / 50
        // );

        migration.vaultCreation.oracle =
            IOracleWrapper(address(oracleWrapper));
        migration.vaultCreation.maxDeviation = PIPS / 50;
        migration.vaultCreation.cooldownPeriod = 60;
        migration.vaultCreation.stratAnnouncer =
            vm.addr(uint256(keccak256(abi.encode("StratAnnouncer"))));
        migration.vaultCreation.maxSlippage = PIPS / 50;

        migration.executor =
            vm.addr(uint256(keccak256(abi.encode("Executor"))));

        // #endregion migration payload.

        // #region whitelist migration module.

        vm.prank(GELOwner);
        IGnosisSafe(GELOwner).enableModule(address(migrationHelper));

        assertEq(IGnosisSafe(GELOwner).isModuleEnabled(address(migrationHelper)), true);

        // #endregion whitelist migration module.

        // #region do migration.

        vm.prank(arrakisTimeLock);
        migrationHelper.migrateVault(migration);

        // #endregion do migration.

        assertEq(IGnosisSafe(GELOwner).isModuleEnabled(address(migrationHelper)), false);
    }

    // #endregion test migration module constructor.

    // #endregion migration module.

    // #region internal functions.

    function _addressOf(
        bytes32 _salt
    ) internal view returns (address) {
        address proxy = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            factory,
                            _salt,
                            bytes32(
                                0x21c35dbe1b344a2488cf3321d6ce542f8e9f305544ff09e4993a62319a497c1f
                            )
                        )
                    )
                )
            )
        );

        return address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(hex"d694", proxy, hex"01")
                    )
                )
            )
        );
    }

    function _getSignature(
        bytes32 txHash
    ) internal pure returns (bytes memory signatures) {
        // #region create a signature.

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(10, txHash);

        signatures =
            bytes.concat(signatures, abi.encodePacked(r, s, v));

        (v, r, s) = vm.sign(11, txHash);

        signatures =
            bytes.concat(signatures, abi.encodePacked(r, s, v));

        // #endregion create a signature.
    }

    function _setup() internal {
        // #region uniswap setup.

        poolManager = _deployPoolManager();

        // #endregion uniswap setup.

        // #region create router v2.

        router = _deployArrakisPrivateRouter();

        // #endregion create router v2.

        // #region create routerSwapExecutor.

        swapExecutor = _deployRouterSwapExecutor(router);

        // #endregion create routerSwapExecutor.

        // #region initialize router.

        vm.prank(owner);

        ArrakisPrivateVaultRouter(payable(router)).updateSwapExecutor(
            swapExecutor
        );

        // #endregion initialize router.

        // #region create an uniswap standard module.

        _deployUniswapStandardModule(poolManager);

        // #endregion create an uniswap standard module.

        // #region whitelist uniswap module beacon inside the registry.

        address[] memory beacons = new address[](1);
        beacons[0] = uniswapStandardModuleBeacon;

        vm.startPrank(IOwnable(privateRegistry).owner());

        IModuleRegistry(privateRegistry).whitelistBeacons(beacons);

        vm.stopPrank();

        // #endregion whitelist uniswap module beacon inside the registry.
    }

    function _deployPoolManager() internal returns (address pm) {
        address poolManagerOwner = vm.addr(
            uint256(keccak256(abi.encode("PoolManagerOwner")))
        );

        pm = address(new PoolManager(poolManagerOwner));
    }

    function _deployArrakisPrivateRouter()
        internal
        returns (address routerV2)
    {
        return address(
            new ArrakisPrivateVaultRouter(
                NATIVE_COIN, permit2, owner, factory, WETH
            )
        );
    }

    function _deployRouterSwapExecutor(
        address router
    ) internal returns (address swapExecutor) {
        return address(
            new PrivateRouterSwapExecutor(router, NATIVE_COIN)
        );
    }

    function _deployUniswapStandardModule(
        address poolManager_
    ) internal {
        // #region create uniswap standard module.

        uniswapStandardModuleImplementation = address(
            new UniV4StandardModulePrivate(poolManager, guardian)
        );

        uniswapStandardModuleBeacon = address(
            new UpgradeableBeacon(uniswapStandardModuleImplementation)
        );

        UpgradeableBeacon(uniswapStandardModuleBeacon)
            .transferOwnership(arrakisTimeLock);

        // #endregion create uniswap standard module.
    }

    // #endregion internal functions.
}
