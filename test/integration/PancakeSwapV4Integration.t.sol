// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// #region foundry.
import {TestWrapper} from "../utils/TestWrapper.sol";
import {console} from "forge-std/console.sol";
// #endregion foundry.

import {IArrakisLPModule} from
    "../../src/interfaces/IArrakisLPModule.sol";
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
    TEN_PERCENT,
    PIPS
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
import {IGuardian} from "../../src/interfaces/IGuardian.sol";
import {IModuleRegistry} from
    "../../src/interfaces/IModuleRegistry.sol";
import {IPauser} from "../../src/interfaces/IPauser.sol";
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
import {IPancakeDistributor} from
    "../../src/interfaces/IPancakeDistributor.sol";

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

// #region pancake v4.
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
import {FullMath} from
    "@pancakeswap/v4-core/src/pool-cl/libraries/FullMath.sol";
import {Hashes} from
    "@pancakeswap/v4-core/lib/openzeppelin-contracts/contracts/utils/cryptography/Hashes.sol";

// #endregion pancake v4.

import {LiquidityAmounts} from
    "@v3-lib-0.8/contracts/LiquidityAmounts.sol";

// #region valantis mocks.

import {OracleWrapper} from "./mocks/OracleWrapper.sol";

// #endregion valantis mocks.

// #region utils.

import {IPancakeDistributorExtension} from
    "./utils/IPancakeDistributorExtension.sol";

// #endregion utils.

contract PancakeSwapV4IntegrationTest is
    TestWrapper,
    ILockCallback
{
    using SafeERC20 for IERC20Metadata;
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;

    // #region constant properties.
    address public constant WETH =
        0x2170Ed0880ac9A755fd29B2688956BD959F933F8;
    address public constant USDT =
        0x55d398326f99059fF775485246999027B3197955;
    address public constant USDC =
        0x8965349fb649A33a30cbFDa057D8eC2C48AbE2A2;
    address public constant AAVE =
        0xfb6115445Bff7b52FeB98650C87f44907E58f802;
    address public constant CAKE =
        0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82;

    address public constant distributor =
        0xEA8620aAb2F07a0ae710442590D649ADE8440877;
    address public constant distributorAdmin =
        0xfb0B4c408eA60BbFc099fB6FC160052D7215375e;
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
    // #endregion arrakis modular contracts.

    address public owner;

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

    // #region pancake.

    address public poolManager;
    address public pancakeVault;

    // #endregion pancake.

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

        _reset(vm.envString("BSC_RPC_URL"), 59_854_309);

        // #endregion reset fork.

        // #region setup.

        owner = vm.addr(uint256(keccak256(abi.encode("Owner"))));

        /// @dev we will not use it so we mock it.
        privateModule =
            vm.addr(uint256(keccak256(abi.encode("Private Module"))));
        executor = vm.addr(uint256(keccak256(abi.encode("Executor"))));
        stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strategy Announcer")))
        );
        deployer = vm.addr(uint256(keccak256(abi.encode("Deployer"))));

        (token0, token1) =
            (IERC20Metadata(WETH), IERC20Metadata(USDC));

        // #region create an oracle.

        oracle = address(new OracleWrapper());

        // #endregion create an oracle.

        // #endregion setup.

        _setup();

        // #region create a pancake v4 pool.

        Currency currency0 = Currency.wrap(WETH);
        Currency currency1 = Currency.wrap(USDC);

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

        // #endregion create a pancake v4 pool.

        // #region create a vault.

        bytes32 salt =
            keccak256(abi.encode("Public vault Pancake V4 salt"));
        init0 = 1e18;
        init1 = 2000e18;
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
            WETH,
            USDC,
            owner,
            pancakeSwapStandardModuleBeacon,
            moduleCreationPayload,
            initManagementPayload
        );
    }

    // #region pancake v4 callback function.

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

    // #endregion pancake v4 callback function.

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
            .computeMintAmounts(2000e18, 1e18, 1e18, 0, 0);
    }

    // #endregion test resolver constructor.

    // #region test.

    function test_addLiquidity() public {
        (uint256 sharesToMint, uint256 amount0, uint256 amount1) =
        IArrakisPublicVaultRouterV2(router).getMintAmounts(
            vault, init0 / 3, init1
        );

        address user = vm.addr(uint256(keccak256(abi.encode("User"))));

        deal(WETH, user, amount0);

        deal(USDC, user, amount1);

        // #region approve router.

        vm.startPrank(user);

        IERC20Metadata(WETH).approve(router, amount0);
        IERC20Metadata(USDC).approve(router, amount1);

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

        tokens[0] = USDT;
        tokens[1] = AAVE;
        amounts[0] = type(uint256).max;
        amounts[1] = type(uint256).max;

        vm.stopPrank();

        uint256 cakeBalance =
            IERC20Metadata(CAKE).balanceOf(distributor);

        IPancakeDistributor.ClaimParams[] memory params =
            new IPancakeDistributor.ClaimParams[](1);
        IPancakeDistributor.ClaimEscrowed[] memory escrowed =
            new IPancakeDistributor.ClaimEscrowed[](0);

        params[0].proof = new bytes32[](1);
        params[0].token = CAKE;
        params[0].amount = IPancakeDistributorExtension(distributor)
            .claimedAmounts(CAKE, module) + 1_000_000_000_000_000_000;
        // params[0].proof[0] = keccak256(bytes.concat(keccak256(abi.encode(block.chainid, module, CAKE, params[0].amount))));
        params[0].proof[0] = keccak256(abi.encode("TOTO"));

        bytes32 root = Hashes.commutativeKeccak256(
            params[0].proof[0],
            keccak256(
                bytes.concat(
                    keccak256(
                        abi.encode(
                            block.chainid,
                            module,
                            CAKE,
                            params[0].amount
                        )
                    )
                )
            )
        );

        vm.warp(
            IPancakeDistributorExtension(distributor)
                .endOfDisputePeriod() + 1
        );

        vm.prank(distributorAdmin);
        IPancakeDistributorExtension(distributor).setMerkleTree(
            root, keccak256(abi.encode("IpfsHash"))
        );

        bytes32[][] memory proofs = new bytes32[][](2);
        address[] memory users = new address[](2);
        tokens = new address[](2);
        amounts = new uint256[](2);
        proofs[0] = new bytes32[](1);
        proofs[0][0] = keccak256(abi.encode(module, USDT, 2000e18));
        users[0] = module;
        tokens[0] = AAVE;
        amounts[0] = 1e18;
        proofs[1] = new bytes32[](1);
        proofs[1][0] = keccak256(abi.encode(module, AAVE, 1e18));
        users[1] = module;
        tokens[1] = USDT;
        amounts[1] = 2000e18;

        vm.warp(
            IPancakeDistributorExtension(distributor)
                .endOfDisputePeriod() + 1
        );

        vm.prank(distributorAdmin);
        IPancakeDistributorExtension(distributor).setMerkleTree(
            proofs[0][0] < proofs[1][0]
                ? keccak256(abi.encode(proofs[0][0], proofs[1][0]))
                : keccak256(abi.encode(proofs[1][0], proofs[0][0])),
            keccak256("IPFS_HASH")
        );

        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));

        assertEq(IERC20Metadata(CAKE).balanceOf(receiver), 0);

        address managerReceiver =
            vm.addr(uint256(keccak256(abi.encode("ManagerReceiver"))));

        vm.prank(IOwnable(arrakisStandardManager).owner());
        IPancakeSwapV4StandardModule(module).setReceiver(
            managerReceiver
        );

        vm.prank(IOwnable(vault).owner());
        IPancakeSwapV4StandardModule(module).claimRewards(
            params, escrowed, receiver
        );

        uint256 managerFeePIPS =
            IArrakisLPModule(module).managerFeePIPS();

        address rewardReceiver =
            IPancakeSwapV4StandardModule(module).rewardReceiver();

        assertEq(
            IERC20Metadata(CAKE).balanceOf(receiver),
            FullMath.mulDiv(
                1_000_000_000_000_000_000, managerFeePIPS, PIPS
            )
        );

        assertEq(
            IERC20Metadata(CAKE).balanceOf(rewardReceiver),
            FullMath.mulDiv(
                1_000_000_000_000_000_000, managerFeePIPS, PIPS
            )
        );

        // #endregion merkl rewards.
    }

    function test_add_Liquidity_Escrowed() public {
        (uint256 sharesToMint, uint256 amount0, uint256 amount1) =
        IArrakisPublicVaultRouterV2(router).getMintAmounts(
            vault, init0 / 3, init1
        );

        address user = vm.addr(uint256(keccak256(abi.encode("User"))));

        deal(WETH, user, amount0);

        deal(USDC, user, amount1);

        // #region approve router.

        vm.startPrank(user);

        IERC20Metadata(WETH).approve(router, amount0);
        IERC20Metadata(USDC).approve(router, amount1);

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

        tokens[0] = USDT;
        tokens[1] = AAVE;
        amounts[0] = type(uint256).max;
        amounts[1] = type(uint256).max;

        vm.stopPrank();

        uint256 cakeBalance =
            IERC20Metadata(CAKE).balanceOf(distributor);

        IPancakeDistributor.ClaimParams[] memory params =
            new IPancakeDistributor.ClaimParams[](1);
        IPancakeDistributor.ClaimEscrowed[] memory escrowed;

        params[0].proof = new bytes32[](1);
        params[0].token = CAKE;
        params[0].amount = IPancakeDistributorExtension(distributor)
            .claimedAmounts(CAKE, module) + 1_000_000_000_000_000_000;
        // params[0].proof[0] = keccak256(bytes.concat(keccak256(abi.encode(block.chainid, module, CAKE, params[0].amount))));
        params[0].proof[0] = keccak256(abi.encode("TOTO"));

        bytes32 root = Hashes.commutativeKeccak256(
            params[0].proof[0],
            keccak256(
                bytes.concat(
                    keccak256(
                        abi.encode(
                            block.chainid,
                            module,
                            CAKE,
                            params[0].amount
                        )
                    )
                )
            )
        );

        vm.warp(
            IPancakeDistributorExtension(distributor)
                .endOfDisputePeriod() + 1
        );

        vm.prank(distributorAdmin);
        IPancakeDistributorExtension(distributor).setMerkleTree(
            root, keccak256(abi.encode("IpfsHash"))
        );

        bytes32[][] memory proofs = new bytes32[][](2);
        address[] memory users = new address[](2);
        tokens = new address[](2);
        amounts = new uint256[](2);
        proofs[0] = new bytes32[](1);
        proofs[0][0] = keccak256(abi.encode(module, USDT, 2000e18));
        users[0] = module;
        tokens[0] = AAVE;
        amounts[0] = 1e18;
        proofs[1] = new bytes32[](1);
        proofs[1][0] = keccak256(abi.encode(module, AAVE, 1e18));
        users[1] = module;
        tokens[1] = USDT;
        amounts[1] = 2000e18;

        vm.warp(
            IPancakeDistributorExtension(distributor)
                .endOfDisputePeriod() + 1
        );

        vm.prank(distributorAdmin);
        IPancakeDistributorExtension(distributor).setMerkleTree(
            proofs[0][0] < proofs[1][0]
                ? keccak256(abi.encode(proofs[0][0], proofs[1][0]))
                : keccak256(abi.encode(proofs[1][0], proofs[0][0])),
            keccak256("IPFS_HASH")
        );

        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));

        assertEq(IERC20Metadata(CAKE).balanceOf(receiver), 0);

        address managerReceiver =
            vm.addr(uint256(keccak256(abi.encode("ManagerReceiver"))));

        vm.prank(IOwnable(arrakisStandardManager).owner());
        IPancakeSwapV4StandardModule(module).setReceiver(
            managerReceiver
        );

        vm.prank(arrakisStandardManager);
        IPancakeSwapV4StandardModule(module).claimManagerRewards(
            params
        );

        uint256 managerFeePIPS =
            IArrakisLPModule(module).managerFeePIPS();

        address rewardReceiver =
            IPancakeSwapV4StandardModule(module).rewardReceiver();

        assertEq(
            IERC20Metadata(CAKE).balanceOf(rewardReceiver),
            FullMath.mulDiv(
                1_000_000_000_000_000_000, managerFeePIPS, PIPS
            )
        );

        // #region do escrow rewards claim.

        params = new IPancakeDistributor.ClaimParams[](0);
        escrowed = new IPancakeDistributor.ClaimEscrowed[](1);

        escrowed[0] = IPancakeDistributor.ClaimEscrowed({
            token: CAKE,
            amount: 1_000_000_000_000_000_000
                - FullMath.mulDiv(
                    1_000_000_000_000_000_000, managerFeePIPS, PIPS
                )
        });

        vm.prank(IOwnable(vault).owner());
        IPancakeSwapV4StandardModule(module).claimRewards(
            params, escrowed, receiver
        );

        // #endregion do escrow rewards claim.

        console.log("ManagerFeePIPS : ", managerFeePIPS);

        assertEq(
            IERC20Metadata(CAKE).balanceOf(receiver),
            FullMath.mulDiv(
                1_000_000_000_000_000_000, managerFeePIPS, PIPS
            )
        );

        // #endregion merkl rewards.
    }

    // #region sub section claimRewards/claimManagerRewards.

    function test_claimRewards_only_meta_vault_owner() public {
        address module = address(IArrakisMetaVault(vault).module());

        IPancakeDistributor.ClaimParams[] memory params;
        IPancakeDistributor.ClaimEscrowed[] memory escrowed;
        address receiver = address(0);

        vm.expectRevert(
            IPancakeSwapV4StandardModule.OnlyMetaVaultOwner.selector
        );

        IPancakeSwapV4StandardModule(module).claimRewards(
            params, escrowed, receiver
        );
    }

    function test_claimRewards_receiver_address_zero() public {
        address module = address(IArrakisMetaVault(vault).module());

        IPancakeDistributor.ClaimParams[] memory params;
        IPancakeDistributor.ClaimEscrowed[] memory escrowed;
        address receiver = address(0);

        vm.prank(IOwnable(vault).owner());
        vm.expectRevert(IArrakisLPModule.AddressZero.selector);
        IPancakeSwapV4StandardModule(module).claimRewards(
            params, escrowed, receiver
        );
    }

    function test_claimRewards_claim_params_length_zero() public {
        address module = address(IArrakisMetaVault(vault).module());

        IPancakeDistributor.ClaimParams[] memory params;
        IPancakeDistributor.ClaimEscrowed[] memory escrowed;
        address receiver = vm.addr(1);

        vm.prank(IOwnable(vault).owner());
        vm.expectRevert(
            IPancakeSwapV4StandardModule
                .ClaimParamsLengthZero
                .selector
        );
        IPancakeSwapV4StandardModule(module).claimRewards(
            params, escrowed, receiver
        );
    }

    // #endregion sub section claimRewards/claimManagerRewards.

    function test_addLiquidityMaxAmountsTooLow() public {
        (uint256 sharesToMint, uint256 amount0, uint256 amount1) =
        IArrakisPublicVaultRouterV2(router).getMintAmounts(
            vault, init0 / 3, init1
        );

        address user = vm.addr(uint256(keccak256(abi.encode("User"))));

        deal(WETH, user, amount0);

        deal(USDC, user, amount1);

        // #region approve router.

        vm.startPrank(user);

        IERC20Metadata(WETH).approve(router, amount0);
        IERC20Metadata(USDC).approve(router, amount1);

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

        deal(WETH, user, amount0);
        deal(USDC, user, amount1);

        // #region approve router.

        vm.startPrank(user);

        IERC20Metadata(WETH).approve(router, amount0);
        IERC20Metadata(USDC).approve(router, amount1);

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

        deal(USDC, secondUser, amount1);
        deal(WETH, secondUser, amount0);

        // #region approve router.

        vm.startPrank(secondUser);

        IERC20Metadata(WETH).approve(router, amount0);
        IERC20Metadata(USDC).approve(router, amount1);

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
        init1 = 2000e18;
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
            WETH,
            USDC,
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

        deal(WETH, user, amount0);
        deal(USDC, user, amount1);

        // #region approve router.

        vm.startPrank(user);

        IERC20Metadata(WETH).approve(router, amount0);
        IERC20Metadata(USDC).approve(router, amount1);

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

        deal(WETH, secondUser, amount0);
        deal(USDC, secondUser, amount1);

        // #region approve router.

        vm.startPrank(secondUser);

        IERC20Metadata(WETH).approve(router, amount0);
        IERC20Metadata(USDC).approve(router, amount1);

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
        init0 = 1e18;
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
            WETH,
            USDC,
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

        deal(WETH, user, amount0);
        deal(USDC, user, amount1);

        // #region approve router.

        vm.startPrank(user);

        IERC20Metadata(WETH).approve(router, amount0);
        IERC20Metadata(USDC).approve(router, amount1);

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

        deal(WETH, secondUser, amount0);
        deal(USDC, secondUser, amount1);

        // #region approve router.

        vm.startPrank(secondUser);

        IERC20Metadata(WETH).approve(router, amount0);
        IERC20Metadata(USDC).approve(router, amount1);

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

        deal(WETH, user, amount0);

        deal(USDC, user, amount1);

        // #region approve router.

        vm.startPrank(user);

        IERC20Metadata(WETH).approve(router, amount0);
        IERC20Metadata(USDC).approve(router, amount1);

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

        deal(WETH, secondUser, amount0);
        deal(USDC, secondUser, amount1);

        // #region approve router.

        vm.startPrank(secondUser);

        IERC20Metadata(WETH).approve(router, init0);
        IERC20Metadata(USDC).approve(router, init1 / 3);

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

        // #region pancake setup.

        (poolManager, pancakeVault) = _deployPoolManager();

        // #endregion pancake setup.

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

        // #region create an pancake standard module.

        _deployPancakeSwapStandardModule(poolManager);

        // #endregion create an pancake standard module.

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
        // #region create pancake standard module.

        pancakeSwapStandardModuleImplementation = address(
            new PancakeSwapV4StandardModulePublic(
                poolManager, guardian, pancakeVault, distributor
            )
        );
        pancakeSwapStandardModuleBeacon = address(
            new UpgradeableBeacon(
                pancakeSwapStandardModuleImplementation
            )
        );

        UpgradeableBeacon(pancakeSwapStandardModuleBeacon)
            .transferOwnership(arrakisTimeLock);

        // #endregion create pancake standard module.
    }

    function _deployArrakisPublicRouter()
        internal
        returns (address routerV2)
    {
        return address(
            new ArrakisPublicVaultRouterV2(
                NATIVE_COIN, permit2, owner, factory, WETH
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
