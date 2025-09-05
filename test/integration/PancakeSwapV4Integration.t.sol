// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// #region foundry.
import {TestWrapper} from "../utils/TestWrapper.sol";
import {console} from "forge-std/console.sol";
// #endregion foundry.

import {PancakeSwapV4StandardModulePublic} from
    "../../src/modules/PancakeSwapV4StandardModulePublic.sol";
import {BunkerModule} from "../../src/modules/BunkerModule.sol";
import {ArrakisPublicVaultRouterV2} from
    "../../src/ArrakisPublicVaultRouterV2.sol";
import {RouterSwapExecutor} from "../../src/RouterSwapExecutor.sol";
import {PancakeSwapV4StandardModuleResolver} from
    "../../src/modules/resolvers/PancakeSwapV4StandardModuleResolver.sol";
import {
    NATIVE_COIN,
    TEN_PERCENT
} from "../../src/constants/CArrakis.sol";
import {IArrakisMetaVault} from
    "../../src/interfaces/IArrakisMetaVault.sol";

// #region interfaces.

import {IArrakisMetaVaultFactory} from
    "../../src/interfaces/IArrakisMetaVaultFactory.sol";
import {IArrakisPrivateVaultRouter} from
    "../../src/interfaces/IArrakisPrivateVaultRouter.sol";
import {IArrakisPublicVaultRouter} from
    "../../src/interfaces/IArrakisPublicVaultRouter.sol";
import {
    IArrakisPublicVaultRouterV2,
    AddLiquidityData
} from "../../src/interfaces/IArrakisPublicVaultRouterV2.sol";
import {IArrakisStandardManager} from
    "../../src/interfaces/IArrakisStandardManager.sol";
import {IModuleRegistry} from
    "../../src/interfaces/IModuleRegistry.sol";
import {IRouterSwapExecutor} from
    "../../src/interfaces/IRouterSwapExecutor.sol";
import {IRouterSwapResolver} from
    "../../src/interfaces/IRouterSwapResolver.sol";
import {IOwnable} from "../../src/interfaces/IOwnable.sol";
import {
    IPancakeSwapV4StandardModule,
    SwapPayload
} from "../../src/interfaces/IPancakeSwapV4StandardModule.sol";
import {IOracleWrapper} from "../../src/interfaces/IOracleWrapper.sol";
import {IPancakeSwapV4StandardModuleResolver} from
    "../../src/interfaces/IPancakeSwapV4StandardModuleResolver.sol";

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

// #endregion openzeppelin.

// #region uniswap v4.
import {IPoolManager} from
    "@pancakeswap/v4-core/src/interfaces/IPoolManager.sol";
import {Vault, IVault} from "@pancakeswap/v4-core/src/Vault.sol";
import {CLPoolManager} from
    "@pancakeswap/v4-core/src/pool-cl/CLPoolManager.sol";
import {ICLPoolManager} from
    "@pancakeswap/v4-core/src/pool-cl/interfaces/ICLPoolManager.sol";
import {
    Currency,
    CurrencyLibrary
} from "@pancakeswap/v4-core/src/types/Currency.sol";
import {
    PoolKey,
    PoolIdLibrary
} from "@pancakeswap/v4-core/src/types/PoolKey.sol";
import {IHooks} from "@pancakeswap/v4-core/src/interfaces/IHooks.sol";
import {TickMath} from
    "@pancakeswap/v4-core/src/pool-cl/libraries/TickMath.sol";
import {ILockCallback} from
    "@pancakeswap/v4-core/src/interfaces/ILockCallback.sol";
import {CLPoolParametersHelper} from
    "@pancakeswap/v4-core/src/pool-cl/libraries/CLPoolParametersHelper.sol";

// #endregion uniswap v4.

import {LiquidityAmounts} from
    "@v3-lib-0.8/contracts/LiquidityAmounts.sol";

// #region valantis mocks.

import {OracleWrapper} from "./mocks/OracleWrapper.sol";
import {CollectorMock} from "./mocks/CollectorMock.sol";

// #endregion valantis mocks.

// #region utils.

import {IDistributorExtension} from
    "./utils/IDistributorExtension.sol";

// #endregion utils.

contract UniswapV4IntegrationTest is TestWrapper, ILockCallback {
    using SafeERC20 for IERC20Metadata;
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;

    // #region constant properties.
    address public constant WETH =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDT =
        0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public constant AAVE =
        0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9;

    address public constant distributor =
        0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae;
    address public constant distributorGovernor =
        0x529619a10129396a2F642cae32099C1eA7FA2834;
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
    address public constant valantisModuleBeacon =
        0xE973Cf1e347EcF26232A95dBCc862AA488b0351b;
    address public constant permit2 =
        0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address public constant weth =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    // #endregion arrakis modular contracts.

    address public owner;
    address public collector;

    address public bunkerImplementation;
    address public bunkerBeacon;

    /// @dev should be used as a private module.
    address public pancakeSwapStandardModuleImplementation;
    address public pancakeSwapStandardModuleBeacon;

    address public privateModule;
    address public vault;
    address public executor;
    address public stratAnnouncer;

    // #region arrakis.

    address public router;
    address public swapExecutor;
    address public pancakeSwapV4resolver;

    // #endregion arrakis.

    // #region uniswap.

    address public poolManager;
    address public pancakeVault;

    // #endregion uniswap.

    // #region mocks.

    address public oracle;
    address public deployer;

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

    function setUp() public {
        // #region reset fork.

        _reset(vm.envString("ETH_RPC_URL"), 20_792_200);

        // #endregion reset fork.

        // #region setup.

        owner = vm.addr(uint256(keccak256(abi.encode("Owner"))));
        collector = address(new CollectorMock(distributor));

        /// @dev we will not use it so we mock it.
        privateModule =
            vm.addr(uint256(keccak256(abi.encode("Private Module"))));
        executor = vm.addr(uint256(keccak256(abi.encode("Executor"))));
        stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strategy Announcer")))
        );
        deployer = vm.addr(uint256(keccak256(abi.encode("Deployer"))));

        (token0, token1) =
            (IERC20Metadata(USDC), IERC20Metadata(WETH));

        // #region create an oracle.

        oracle = address(new OracleWrapper());

        // #endregion create an oracle.

        // #endregion setup.

        _setup();

        // #region create a uniswap v4 pool.

        Currency currency0 = Currency.wrap(USDC);
        Currency currency1 = Currency.wrap(WETH);

        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            poolManager: IPoolManager(poolManager),
            fee: 10_000,
            hooks: IHooks(address(0)),
            parameters: CLPoolParametersHelper.setTickSpacing(
                bytes32(0), 10
            )
        });

        sqrtPriceX96 = 1_356_476_084_642_877_807_665_053_548_195_417;

        IVault(pancakeVault).lock(abi.encode(0));

        // #endregion create a uniswap v4 pool.

        // #region create a vault.

        bytes32 salt =
            keccak256(abi.encode("Public vault Univ4 salt"));
        init0 = 2000e6;
        init1 = 1e18;
        maxSlippage = 10_000;

        bytes memory moduleCreationPayload = abi.encodeWithSelector(
            IPancakeSwapV4StandardModule.initialize.selector,
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

        // #endregion create a vault.

        vm.prank(deployer);
        vault = IArrakisMetaVaultFactory(factory).deployPublicVault(
            salt,
            USDC,
            WETH,
            owner,
            pancakeSwapStandardModuleBeacon,
            moduleCreationPayload,
            initManagementPayload
        );
    }

    // #region uniswap v4 callback function.

    function lockAcquired(
        bytes calldata data
    ) public returns (bytes memory) {
        uint256 typeOfLockAcquired = abi.decode(data, (uint256));

        if (typeOfLockAcquired == 0) {
            ICLPoolManager(poolManager).initialize(
                poolKey, sqrtPriceX96
            );
        }
    }

    // #endregion uniswap v4 callback function.

    // #region test resolver constructor.

    function testResolverConstructorAddressZero() public {
        vm.expectRevert(
            IPancakeSwapV4StandardModuleResolver.AddressZero.selector
        );
        new PancakeSwapV4StandardModuleResolver(address(0));
    }

    function test_compute_mint_amounts_mint_zero() public {
        vm.expectRevert(
            IPancakeSwapV4StandardModuleResolver.MintZero.selector
        );
        IPancakeSwapV4StandardModuleResolver(pancakeSwapV4resolver)
            .computeMintAmounts(2000e6, 1e18, 1e18, 0, 0);
    }

    // #endregion test resolver constructor.

    // #region test.

    function test_addLiquidity() public {
        (uint256 sharesToMint, uint256 amount0, uint256 amount1) =
        IArrakisPublicVaultRouterV2(router).getMintAmounts(
            vault, init0 / 3, init1
        );

        address user = vm.addr(uint256(keccak256(abi.encode("User"))));

        deal(WETH, user, amount1);

        deal(USDC, user, amount0);

        // #region approve router.

        vm.startPrank(user);

        IERC20Metadata(USDC).approve(router, amount0);
        IERC20Metadata(WETH).approve(router, amount1);

        // #endregion approve router.

        // #region add liquidity.

        IArrakisPublicVaultRouterV2(router).addLiquidity(
            AddLiquidityData({
                amount0Max: amount0,
                amount1Max: amount1,
                amount0Min: amount0 * 99 / 100,
                amount1Min: amount1 * 99 / 100,
                amountSharesMin: sharesToMint * 99 / 100,
                vault: vault,
                receiver: user
            })
        );

        vm.stopPrank();

        // #endregion add liquidity.

        // #region merkl rewards.

        address module = address(IArrakisMetaVault(vault).module());

        vm.startPrank(IOwnable(vault).owner());

        address[] memory tokens = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        tokens[0] = AAVE;
        tokens[1] = USDT;
        amounts[0] = type(uint256).max;
        amounts[1] = type(uint256).max;

        IPancakeSwapV4StandardModule(module).approve(
            collector, tokens, amounts
        );
        vm.stopPrank();

        uint256 uSDTBalance =
            IERC20Metadata(USDT).balanceOf(distributor);
        uint256 aAVEBalance =
            IERC20Metadata(AAVE).balanceOf(distributor);

        bytes32[][] memory proofs = new bytes32[][](2);
        address[] memory users = new address[](2);
        tokens = new address[](2);
        amounts = new uint256[](2);
        proofs[0] = new bytes32[](1);
        proofs[0][0] = keccak256(abi.encode(module, USDT, 2000e6));
        users[0] = module;
        tokens[0] = AAVE;
        amounts[0] = 1e18;
        proofs[1] = new bytes32[](1);
        proofs[1][0] = keccak256(abi.encode(module, AAVE, 1e18));
        users[1] = module;
        tokens[1] = USDT;
        amounts[1] = 2000e6;

        vm.prank(distributorGovernor);
        IDistributorExtension(distributor).updateTree(
            IDistributorExtension.MerkleTree({
                merkleRoot: proofs[0][0] < proofs[1][0]
                    ? keccak256(abi.encode(proofs[0][0], proofs[1][0]))
                    : keccak256(abi.encode(proofs[1][0], proofs[0][0])),
                ipfsHash: keccak256("IPFS_HASH")
            })
        );

        vm.warp(
            IDistributorExtension(distributor).endOfDisputePeriod()
                + 1
        );

        deal(USDT, distributor, uSDTBalance + amounts[1]);
        deal(AAVE, distributor, aAVEBalance + amounts[0]);

        uSDTBalance = IERC20Metadata(USDT).balanceOf(distributor);
        aAVEBalance = IERC20Metadata(AAVE).balanceOf(distributor);

        uSDTBalance = IERC20Metadata(USDT).balanceOf(collector);
        aAVEBalance = IERC20Metadata(AAVE).balanceOf(collector);

        CollectorMock(collector).claim(users, tokens, amounts, proofs);
        CollectorMock(collector).transferFrom(
            AAVE, module, amounts[0]
        );
        CollectorMock(collector).transferFrom(
            USDT, module, amounts[1]
        );

        assertEq(
            IERC20Metadata(USDT).balanceOf(collector),
            uSDTBalance + amounts[1]
        );
        assertEq(
            IERC20Metadata(AAVE).balanceOf(collector),
            aAVEBalance + amounts[0]
        );

        // #endregion merkl rewards.
    }

    function test_addLiquidityMaxAmountsTooLow() public {
        (uint256 sharesToMint, uint256 amount0, uint256 amount1) =
        IArrakisPublicVaultRouterV2(router).getMintAmounts(
            vault, init0 / 3, init1
        );

        address user = vm.addr(uint256(keccak256(abi.encode("User"))));

        deal(WETH, user, amount1);

        deal(USDC, user, amount0);

        // #region approve router.

        vm.startPrank(user);

        IERC20Metadata(USDC).approve(router, amount0);
        IERC20Metadata(WETH).approve(router, amount1);

        // #endregion approve router.

        // #region add liquidity.

        vm.expectRevert(
            IPancakeSwapV4StandardModuleResolver
                .MaxAmountsTooLow
                .selector
        );
        IArrakisPublicVaultRouterV2(router).addLiquidity(
            AddLiquidityData({
                amount0Max: amount0,
                amount1Max: 0,
                amount0Min: amount0 * 99 / 100,
                amount1Min: amount1 * 99 / 100,
                amountSharesMin: sharesToMint,
                vault: vault,
                receiver: user
            })
        );

        vm.stopPrank();

        // #endregion add liquidity.
    }

    function test_addLiquidity_after_first_deposit() public {
        (uint256 sharesToMint, uint256 amount0, uint256 amount1) =
        IArrakisPublicVaultRouterV2(router).getMintAmounts(
            vault, init0 / 3, init1
        );

        address user = vm.addr(uint256(keccak256(abi.encode("User"))));

        deal(WETH, user, amount1);
        deal(USDC, user, amount0);

        // #region approve router.

        vm.startPrank(user);

        IERC20Metadata(USDC).approve(router, amount0);
        IERC20Metadata(WETH).approve(router, amount1);

        // #endregion approve router.

        // #region add liquidity.

        IArrakisPublicVaultRouterV2(router).addLiquidity(
            AddLiquidityData({
                amount0Max: amount0,
                amount1Max: amount1,
                amount0Min: amount0 * 99 / 100,
                amount1Min: amount1 * 99 / 100,
                amountSharesMin: sharesToMint * 99 / 100,
                vault: vault,
                receiver: user
            })
        );

        vm.stopPrank();

        // #endregion add liquidity.

        // #region second user deposit.

        (sharesToMint, amount0, amount1) = IArrakisPublicVaultRouterV2(
            router
        ).getMintAmounts(vault, init0, init1 / 3);

        address secondUser =
            vm.addr(uint256(keccak256(abi.encode("Second User"))));

        deal(WETH, secondUser, amount1);
        deal(USDC, secondUser, amount0);

        // #region approve router.

        vm.startPrank(secondUser);

        IERC20Metadata(USDC).approve(router, amount0);
        IERC20Metadata(WETH).approve(router, amount1);

        // #endregion approve router.

        IArrakisPublicVaultRouterV2(router).addLiquidity(
            AddLiquidityData({
                amount0Max: amount0,
                amount1Max: amount1,
                amount0Min: amount0 * 99 / 100,
                amount1Min: amount1 * 99 / 100,
                amountSharesMin: sharesToMint * 99 / 100,
                vault: vault,
                receiver: secondUser
            })
        );

        vm.stopPrank();

        // #endregion second user deposit.
    }

    function test_addLiquidity_after_first_deposit_only_token1()
        public
    {
        // #region create a vault.

        bytes32 salt =
            keccak256(abi.encode("Public vault Univ4 salt v2"));
        init0 = 0;
        init1 = 1e18;
        maxSlippage = 10_000;

        bytes memory moduleCreationPayload = abi.encodeWithSelector(
            IPancakeSwapV4StandardModule.initialize.selector,
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

        // #endregion create a vault.

        vm.prank(deployer);
        vault = IArrakisMetaVaultFactory(factory).deployPublicVault(
            salt,
            USDC,
            WETH,
            owner,
            pancakeSwapStandardModuleBeacon,
            moduleCreationPayload,
            initManagementPayload
        );

        (uint256 sharesToMint, uint256 amount0, uint256 amount1) =
        IArrakisPublicVaultRouterV2(router).getMintAmounts(
            vault, 1, init1
        );

        address user = vm.addr(uint256(keccak256(abi.encode("User"))));

        deal(WETH, user, amount1);
        deal(USDC, user, amount0);

        // #region approve router.

        vm.startPrank(user);

        IERC20Metadata(USDC).approve(router, amount0);
        IERC20Metadata(WETH).approve(router, amount1);

        // #endregion approve router.

        // #region add liquidity.

        IArrakisPublicVaultRouterV2(router).addLiquidity(
            AddLiquidityData({
                amount0Max: 1,
                amount1Max: amount1,
                amount0Min: amount0 * 99 / 100,
                amount1Min: amount1 * 99 / 100,
                amountSharesMin: sharesToMint * 99 / 100,
                vault: vault,
                receiver: user
            })
        );

        vm.stopPrank();

        // #endregion add liquidity.

        // #region second user deposit.

        (sharesToMint, amount0, amount1) = IArrakisPublicVaultRouterV2(
            router
        ).getMintAmounts(vault, 1, init1 / 3);

        address secondUser =
            vm.addr(uint256(keccak256(abi.encode("Second User"))));

        deal(WETH, secondUser, amount1);
        deal(USDC, secondUser, amount0);

        // #region approve router.

        vm.startPrank(secondUser);

        IERC20Metadata(USDC).approve(router, amount0);
        IERC20Metadata(WETH).approve(router, amount1);

        // #endregion approve router.

        IArrakisPublicVaultRouterV2(router).addLiquidity(
            AddLiquidityData({
                amount0Max: 1,
                amount1Max: amount1,
                amount0Min: amount0 * 99 / 100,
                amount1Min: amount1 * 99 / 100,
                amountSharesMin: sharesToMint * 99 / 100,
                vault: vault,
                receiver: secondUser
            })
        );

        vm.stopPrank();

        // #endregion second user deposit.
    }

    function test_addLiquidity_after_first_deposit_only_token0()
        public
    {
        // #region create a vault.

        bytes32 salt =
            keccak256(abi.encode("Public vault Univ4 salt v2"));
        init0 = 2000e6;
        init1 = 0;
        maxSlippage = 10_000;

        bytes memory moduleCreationPayload = abi.encodeWithSelector(
            IPancakeSwapV4StandardModule.initialize.selector,
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

        // #endregion create a vault.

        vm.prank(deployer);
        vault = IArrakisMetaVaultFactory(factory).deployPublicVault(
            salt,
            USDC,
            WETH,
            owner,
            pancakeSwapStandardModuleBeacon,
            moduleCreationPayload,
            initManagementPayload
        );

        (uint256 sharesToMint, uint256 amount0, uint256 amount1) =
        IArrakisPublicVaultRouterV2(router).getMintAmounts(
            vault, init0, 1
        );

        address user = vm.addr(uint256(keccak256(abi.encode("User"))));

        deal(WETH, user, amount1);
        deal(USDC, user, amount0);

        // #region approve router.

        vm.startPrank(user);

        IERC20Metadata(USDC).approve(router, amount0);
        IERC20Metadata(WETH).approve(router, amount1);

        // #endregion approve router.

        // #region add liquidity.

        IArrakisPublicVaultRouterV2(router).addLiquidity(
            AddLiquidityData({
                amount0Max: amount0,
                amount1Max: 1,
                amount0Min: amount0 * 99 / 100,
                amount1Min: amount1 * 99 / 100,
                amountSharesMin: sharesToMint * 99 / 100,
                vault: vault,
                receiver: user
            })
        );

        vm.stopPrank();

        // #endregion add liquidity.

        // #region second user deposit.

        (sharesToMint, amount0, amount1) = IArrakisPublicVaultRouterV2(
            router
        ).getMintAmounts(vault, init0 / 3, 1);

        address secondUser =
            vm.addr(uint256(keccak256(abi.encode("Second User"))));

        deal(WETH, secondUser, amount1);
        deal(USDC, secondUser, amount0);

        // #region approve router.

        vm.startPrank(secondUser);

        IERC20Metadata(USDC).approve(router, amount0);
        IERC20Metadata(WETH).approve(router, amount1);

        // #endregion approve router.

        IArrakisPublicVaultRouterV2(router).addLiquidity(
            AddLiquidityData({
                amount0Max: amount0,
                amount1Max: 1,
                amount0Min: amount0 * 99 / 100,
                amount1Min: amount1 * 99 / 100,
                amountSharesMin: sharesToMint * 99 / 100,
                vault: vault,
                receiver: secondUser
            })
        );

        vm.stopPrank();

        // #endregion second user deposit.
    }

    function test_rebalance_then_addLiquidity() public {
        (uint256 sharesToMint, uint256 amount0, uint256 amount1) =
        IArrakisPublicVaultRouterV2(router).getMintAmounts(
            vault, init0, init1
        );

        address user = vm.addr(uint256(keccak256(abi.encode("User"))));

        deal(WETH, user, amount1);

        deal(USDC, user, amount0);

        // #region approve router.

        vm.startPrank(user);

        IERC20Metadata(USDC).approve(router, amount0);
        IERC20Metadata(WETH).approve(router, amount1);

        // #endregion approve router.

        // #region add liquidity.

        IArrakisPublicVaultRouterV2(router).addLiquidity(
            AddLiquidityData({
                amount0Max: init0,
                amount1Max: init1,
                amount0Min: amount0,
                amount1Min: amount1,
                amountSharesMin: sharesToMint,
                vault: vault,
                receiver: user
            })
        );

        (amount0, amount1) =
            IArrakisMetaVault(vault).totalUnderlying();

        vm.stopPrank();

        // #endregion add liquidity.
        {
            // #region rebalance.

            int24 tick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);

            int24 tickLower = (tick / 10) * 10 - (2 * 10);
            int24 tickUpper = (tick / 10) * 10 + (2 * 10);

            IPancakeSwapV4StandardModule.Range memory range =
            IPancakeSwapV4StandardModule.Range({
                tickLower: tickLower,
                tickUpper: tickUpper
            });

            uint128 liquidity = LiquidityAmounts
                .getLiquidityForAmounts(
                sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                amount0,
                amount1
            );

            IPancakeSwapV4StandardModule.LiquidityRange memory
                liquidityRange = IPancakeSwapV4StandardModule
                    .LiquidityRange({
                    range: range,
                    liquidity: SafeCast.toInt128(
                        SafeCast.toInt256(uint256(liquidity))
                    )
                });

            IPancakeSwapV4StandardModule.LiquidityRange[] memory
                liquidityRanges = new IPancakeSwapV4StandardModule
                    .LiquidityRange[](1);

            liquidityRanges[0] = liquidityRange;
            SwapPayload memory swapPayload;

            vm.startPrank(arrakisStandardManager);
            IPancakeSwapV4StandardModule(
                address(IArrakisMetaVault(vault).module())
            ).rebalance(liquidityRanges, swapPayload, 0, 0, 0, 0);
            vm.stopPrank();

            // #endregion rebalance.
        }

        // #region second user deposit.

        (sharesToMint, amount0, amount1) = IArrakisPublicVaultRouterV2(
            router
        ).getMintAmounts(vault, init0, init1 / 3);

        address secondUser =
            vm.addr(uint256(keccak256(abi.encode("Second User"))));

        deal(WETH, secondUser, amount1);
        deal(USDC, secondUser, amount0);

        // #region approve router.

        vm.startPrank(secondUser);

        IERC20Metadata(USDC).approve(router, init0);
        IERC20Metadata(WETH).approve(router, init1 / 3);

        // #endregion approve router.

        IArrakisPublicVaultRouterV2(router).addLiquidity(
            AddLiquidityData({
                amount0Max: init0,
                amount1Max: init1 / 3,
                amount0Min: amount0 * 99 / 100,
                amount1Min: amount1 * 99 / 100,
                amountSharesMin: sharesToMint * 99 / 100,
                vault: vault,
                receiver: secondUser
            })
        );

        vm.stopPrank();

        // #endregion second user deposit.
    }

    // #endregion test.

    // #region internal functions.

    function _setup() internal {
        // #region whitelist a deployer.

        address factoryOwner = IOwnable(factory).owner();

        address[] memory deployers = new address[](1);
        deployers[0] = deployer;

        vm.prank(factoryOwner);
        IArrakisMetaVaultFactory(factory).whitelistDeployer(deployers);

        // #endregion whitelist a deployer.

        // #region uniswap setup.

        (poolManager, pancakeVault) = _deployPoolManager();

        // #endregion uniswap setup.

        // #region create bunker module.

        _deployBunkerModule();

        // #endregion create bunker module.

        // #region create router v2.

        router = _deployArrakisPublicRouter();

        // #endregion create router v2.

        // #region create routerSwapExecutor.

        swapExecutor = _deployRouterSwapExecutor(router);

        // #endregion create routerSwapExecutor.

        // #region create resolver.

        pancakeSwapV4resolver =
            _deployPancakeV4StandardModuleResolver(poolManager);

        // #endregion create resolver.

        // #region initialize router.

        vm.prank(owner);

        ArrakisPublicVaultRouterV2(payable(router)).updateSwapExecutor(
            swapExecutor
        );

        // #endregion initialize router.

        // #region whitelist resolver.

        address[] memory resolvers = new address[](1);
        resolvers[0] = pancakeSwapV4resolver;

        bytes32[] memory ids = new bytes32[](1);
        ids[0] =
            keccak256(abi.encode("PancakeSwapV4StandardModulePublic"));

        vm.prank(owner);
        IArrakisPublicVaultRouterV2(router).setResolvers(
            ids, resolvers
        );

        // #endregion whitelist resolver.

        // #region create an uniswap standard module.

        _deployPancakeSwapStandardModule(poolManager);

        // #endregion create an uniswap standard module.

        address[] memory beacons = new address[](2);
        beacons[0] = bunkerBeacon;
        beacons[1] = pancakeSwapStandardModuleBeacon;

        vm.startPrank(IOwnable(publicRegistry).owner());

        IModuleRegistry(publicRegistry).whitelistBeacons(beacons);
        // IModuleRegistry(privateRegistry).whitelistBeacons(beacons);

        vm.stopPrank();
    }

    function _deployPoolManager()
        internal
        returns (address pm, address pV)
    {
        address poolManagerOwner = vm.addr(
            uint256(keccak256(abi.encode("Pool Manager Owner")))
        );

        vm.prank(poolManagerOwner);
        pV = address(new Vault());
        pm = address(new CLPoolManager(IVault(pV)));

        vm.prank(poolManagerOwner);
        IVault(pV).registerApp(pm);
    }

    function _deployBunkerModule() internal {
        bunkerImplementation = address(new BunkerModule(guardian));

        bunkerBeacon =
            address(new UpgradeableBeacon(bunkerImplementation));

        UpgradeableBeacon(bunkerBeacon).transferOwnership(
            arrakisTimeLock
        );
    }

    function _deployPancakeSwapStandardModule(
        address poolManager_
    ) internal {
        // #region create uniswap standard module.

        pancakeSwapStandardModuleImplementation = address(
            new PancakeSwapV4StandardModulePublic(
                poolManager,
                guardian,
                pancakeVault,
                distributor,
                collector
            )
        );
        pancakeSwapStandardModuleBeacon = address(
            new UpgradeableBeacon(
                pancakeSwapStandardModuleImplementation
            )
        );

        UpgradeableBeacon(pancakeSwapStandardModuleBeacon)
            .transferOwnership(arrakisTimeLock);

        // #endregion create uniswap standard module.
    }

    function _deployArrakisPublicRouter()
        internal
        returns (address routerV2)
    {
        return address(
            new ArrakisPublicVaultRouterV2(
                NATIVE_COIN, permit2, owner, factory, weth
            )
        );
    }

    function _deployRouterSwapExecutor(
        address router
    ) internal returns (address swapExecutor) {
        return address(new RouterSwapExecutor(router, NATIVE_COIN));
    }

    function _deployPancakeV4StandardModuleResolver(
        address poolManager
    ) internal returns (address resolver) {
        return address(
            new PancakeSwapV4StandardModuleResolver(poolManager)
        );
    }

    function _setupETHUSDCVault() internal returns (address vault) {}

    function _setupWETHUSDCVaultForExisting() internal {}

    // #endregion internal functions.
}
