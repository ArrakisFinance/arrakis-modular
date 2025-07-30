// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

// #region foundry.
import {TestWrapper} from "../utils/TestWrapper.sol";
import {console} from "forge-std/console.sol";
// #endregion foundry.

import {PancakeSwapV3StandardModulePrivate} from
    "../../src/modules/PancakeSwapV3StandardModulePrivate.sol";
import {BunkerModule} from "../../src/modules/BunkerModule.sol";
import {
    NATIVE_COIN,
    TEN_PERCENT,
    BASE,
    PIPS
} from "../../src/constants/CArrakis.sol";
import {IArrakisMetaVault} from
    "../../src/interfaces/IArrakisMetaVault.sol";
import {IArrakisMetaVaultPrivate} from
    "../../src/interfaces/IArrakisMetaVaultPrivate.sol";
import {IArrakisMetaVaultFactory} from
    "../../src/interfaces/IArrakisMetaVaultFactory.sol";
import {IArrakisStandardManager} from
    "../../src/interfaces/IArrakisStandardManager.sol";
import {IGuardian} from "../../src/interfaces/IGuardian.sol";
import {IModuleRegistry} from
    "../../src/interfaces/IModuleRegistry.sol";
import {IPauser} from "../../src/interfaces/IPauser.sol";
import {IOwnable} from "../../src/interfaces/IOwnable.sol";
import {IPancakeSwapV3StandardModule} from
    "../../src/interfaces/IPancakeSwapV3StandardModule.sol";
import {
    Rebalance,
    SwapPayload,
    PositionLiquidity,
    Range
} from "../../src/structs/SUniswapV3.sol";
import {IOracleWrapper} from "../../src/interfaces/IOracleWrapper.sol";
import {IUniswapV3PoolVariant} from
    "../../src/interfaces/IUniswapV3PoolVariant.sol";
import {IPancakeDistributor} from
    "../../src/interfaces/IPancakeDistributor.sol";
import {IArrakisLPModule} from
    "../../src/interfaces/IArrakisLPModule.sol";

// #region openzeppelin.

import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {UpgradeableBeacon} from
    "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {SafeCast} from
    "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {IAccessControl} from
    "@openzeppelin/contracts/access/IAccessControl.sol";

// #endregion openzeppelin.

import {LiquidityAmounts} from
    "@v3-lib-0.8/contracts/LiquidityAmounts.sol";
import {TickMath} from "@v3-lib-0.8/contracts/TickMath.sol";
import {FullMath} from "@v3-lib-0.8/contracts/FullMath.sol";

import {IPancakeDistributorExtension} from
    "./utils/IPancakeDistributorExtension.sol";

// #region mocks.

import {Hashes} from
    "@pancakeswap/v4-core/lib/openzeppelin-contracts/contracts/utils/cryptography/Hashes.sol";

import {OracleWrapper} from "./mocks/OracleWrapper.sol";

// #endregion mocks.

// #region interfaces.

interface IUniswapV3SwapCallback {
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external;
}

// #endregion interfaces.

contract PancakeSwapV3StandardModuleTest is
    TestWrapper,
    IUniswapV3SwapCallback
{
    using SafeERC20 for IERC20Metadata;

    // #region constant properties.
    address public constant WETH =
        0x2170Ed0880ac9A755fd29B2688956BD959F933F8;
    address public constant BUSD =
        0x55d398326f99059fF775485246999027B3197955;
    address public constant CAKE =
        0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82;

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

    address public constant privateRegistryOwner =
        0x7ddBE55B78FbDe1B0A0b57cc05EE469ccF700585;

    address public constant distributor =
        0xEA8620aAb2F07a0ae710442590D649ADE8440877;
    address public constant distributorOwner =
        0xfa206DAB60c014bEb6833004D8848910165e6047;
    bytes32 public constant MERKLE_ROOT_SETTER =
        0x4a5561f79cf422ddc88aee07ed24396a108d5ffadb60f190c137922af74b2c39;

    // #endregion arrakis modular contracts.

    // #region pancake swap address.

    /// @dev pool fee = 500, tickSpacing = 10
    address public constant pool =
        0xBe141893E4c6AD9272e8C04BAB7E6a10604501a5;
    address public constant pancakeSwapV3Factory =
        0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865;

    // #endregion pancake swap address.

    address public owner;
    address public collector;
    address public deployer;
    address public rewardReceiver;

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

    // #region vault infos.

    uint256 public init0;
    uint256 public init1;
    uint24 public maxSlippage;
    address public oracle;

    // #endregion vault infos.

    IERC20Metadata public token0;
    IERC20Metadata public token1;

    function setUp() public {
        // #region reset fork.

        _reset(vm.envString("BSC_RPC_URL"), 55_590_662);

        // #endregion reset fork.

        owner = vm.addr(uint256(keccak256(abi.encode("Owner"))));

        /// @dev we will not use it so we mock it.
        executor = vm.addr(uint256(keccak256(abi.encode("Executor"))));
        stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strategy Announcer")))
        );
        deployer = vm.addr(uint256(keccak256(abi.encode("Deployer"))));
        rewardReceiver =
            vm.addr(uint256(keccak256(abi.encode("Reward Receiver"))));

        (token0, token1) =
            (IERC20Metadata(WETH), IERC20Metadata(BUSD));

        // #region create an oracle.

        oracle = address(new OracleWrapper());

        // #endregion create an oracle.

        // #region create a uniswap v3 module and whitelist it.

        _createModuleAndWhitelist();

        // #endregion create a uniswap v3 module and whitelist it.

        /// @dev 2% slippage.
        maxSlippage = 20_000;

        init0 = 1;
        init1 = 1;

        // #region create a uniswap v3 vault.

        bytes memory moduleCreationPayload = abi.encodeWithSelector(
            IPancakeSwapV3StandardModule.initialize.selector,
            init0,
            init1,
            500,
            IOracleWrapper(oracle),
            maxSlippage,
            rewardReceiver
        );

        bytes memory initManagementPayload = abi.encode(
            IOracleWrapper(oracle),
            TEN_PERCENT,
            uint256(60),
            executor,
            stratAnnouncer,
            maxSlippage
        );

        // #endregion create a uniswap v3 vault.

        bytes32 salt =
            bytes32(uint256(keccak256(abi.encode("salt toto"))));

        vm.prank(deployer);
        vault = IArrakisMetaVaultFactory(factory).deployPrivateVault(
            salt,
            WETH,
            BUSD,
            owner,
            pancakeSwapStandardModuleBeacon,
            moduleCreationPayload,
            initManagementPayload
        );
    }

    // #region callback.

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external {
        
    }

    // #endregion callback.

    // #region tests.

    function test_fund_rebalance_withdraw() public {
        uint256 amount0;
        uint256 amount1;
        address module;

        {
            address depositor =
                vm.addr(uint256(keccak256(abi.encode("Depositor"))));

            {
                address[] memory depositors = new address[](1);
                depositors[0] = depositor;

                vm.prank(owner);
                IArrakisMetaVaultPrivate(vault).whitelistDepositors(
                    depositors
                );
            }

            amount0 = 10 * 10 ** 18;
            amount1 = 40_000 * 10 ** 18;

            deal(WETH, depositor, amount0);
            deal(BUSD, depositor, amount1);

            // #region get module address.

            module = address(IArrakisMetaVault(vault).module());

            // #endregion get module address.

            // #region fund.

            vm.startPrank(depositor);

            IERC20Metadata(IArrakisMetaVault(vault).token0())
                .safeApprove(module, amount0);
            IERC20Metadata(IArrakisMetaVault(vault).token1())
                .safeApprove(module, amount1);

            IArrakisMetaVaultPrivate(vault).deposit(amount0, amount1);

            vm.stopPrank();

            // #endregion fund.
        }
        {
            // #region let's do a rebalance.

            int24 lowerTick;
            int24 upperTick;
            Rebalance memory params;

            params.mints = new PositionLiquidity[](1);

            // #region mint.

            (uint160 sqrtPriceX96, int24 tick,,,,,) =
                IUniswapV3PoolVariant(pool).slot0();

            lowerTick = (tick - 100) / 10 * 10;
            upperTick = (tick + 100) / 10 * 10;

            uint128 liquidity = LiquidityAmounts
                .getLiquidityForAmounts(
                sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(lowerTick),
                TickMath.getSqrtRatioAtTick(upperTick),
                amount0,
                amount1
            );

            (params.minDeposit0, params.minDeposit1) =
            LiquidityAmounts.getAmountsForLiquidity(
                sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(lowerTick),
                TickMath.getSqrtRatioAtTick(upperTick),
                liquidity
            );

            params.mints[0] = PositionLiquidity({
                liquidity: liquidity,
                range: Range({lowerTick: lowerTick, upperTick: upperTick})
            });

            // #endregion mint

            vm.prank(arrakisStandardManager);
            IPancakeSwapV3StandardModule(module).rebalance(params);
            // #endregion let's do a rebalance.

            // #region let's do another rebalance.

            params.burns = new PositionLiquidity[](1);
            params.burns[0] = PositionLiquidity({
                liquidity: liquidity,
                range: Range({lowerTick: lowerTick, upperTick: upperTick})
            });

            (params.minBurn0, params.minBurn1) = LiquidityAmounts
                .getAmountsForLiquidity(
                sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(lowerTick),
                TickMath.getSqrtRatioAtTick(upperTick),
                liquidity
            );

            lowerTick = (tick - 1000) / 10 * 10;
            upperTick = (tick + 1000) / 10 * 10;

            liquidity = LiquidityAmounts.getLiquidityForAmounts(
                sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(lowerTick),
                TickMath.getSqrtRatioAtTick(upperTick),
                amount0 - 1, // due to rounding down
                amount1 - 1 // due to rounding down
            );

            (params.minDeposit0, params.minDeposit1) =
            LiquidityAmounts.getAmountsForLiquidity(
                sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(lowerTick),
                TickMath.getSqrtRatioAtTick(upperTick),
                liquidity
            );

            params.mints[0] = PositionLiquidity({
                liquidity: liquidity,
                range: Range({lowerTick: lowerTick, upperTick: upperTick})
            });

            vm.prank(arrakisStandardManager);
            IPancakeSwapV3StandardModule(module).rebalance(params);

            // #endregion let's do another rebalance.
        }

        // #region withdraw.

        uint256 balance0 = token0.balanceOf(owner);
        uint256 balance1 = token1.balanceOf(owner);

        vm.startPrank(owner);

        IArrakisMetaVaultPrivate(vault).withdraw(BASE, owner);

        vm.stopPrank();

        assertEq(token0.balanceOf(owner) - balance0, amount0 - 2);
        assertEq(token1.balanceOf(owner) - balance1, amount1 - 2);

        // #endregion withdraw.
    }

    function test_fund_rebalance_with_swap_and_withdraw() public {
        uint256 amount0;
        uint256 amount1;
        address module;

        {
            address depositor =
                vm.addr(uint256(keccak256(abi.encode("Depositor"))));

            {
                address[] memory depositors = new address[](1);
                depositors[0] = depositor;

                vm.prank(owner);
                IArrakisMetaVaultPrivate(vault).whitelistDepositors(
                    depositors
                );
            }

            amount0 = 2 * (10 * 10 ** 18);
            amount1 = 0;

            deal(WETH, depositor, amount0);
            deal(BUSD, depositor, amount1);

            // #region get module address.

            module = address(IArrakisMetaVault(vault).module());

            // #endregion get module address.

            // #region fund.

            vm.startPrank(depositor);

            IERC20Metadata(IArrakisMetaVault(vault).token0())
                .safeApprove(module, amount0);
            IERC20Metadata(IArrakisMetaVault(vault).token1())
                .safeApprove(module, amount1);

            IArrakisMetaVaultPrivate(vault).deposit(amount0, amount1);

            vm.stopPrank();

            // #endregion fund.
        }
        {
            // #region let's do a rebalance.

            int24 lowerTick;
            int24 upperTick;
            Rebalance memory params;

            // #region swap.

            params.swap = SwapPayload({
                payload: abi.encodeWithSelector(
                    PancakeSwapV3StandardModuleTest.swap.selector,
                    WETH,
                    BUSD,
                    amount0 / 2,
                    40_000 * 10 ** 18
                ),
                router: address(this),
                amountIn: amount0 / 2,
                expectedMinReturn: 40_000 * 10 ** 18,
                zeroForOne: true
            });

            amount1 = 40_000 * 10 ** 18;

            // #endregion swap.

            params.mints = new PositionLiquidity[](1);

            // #region mint.

            (uint160 sqrtPriceX96, int24 tick,,,,,) =
                IUniswapV3PoolVariant(pool).slot0();

            lowerTick = (tick - 100) / 10 * 10;
            upperTick = (tick + 100) / 10 * 10;

            uint128 liquidity = LiquidityAmounts
                .getLiquidityForAmounts(
                sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(lowerTick),
                TickMath.getSqrtRatioAtTick(upperTick),
                amount0,
                amount1
            );

            (params.minDeposit0, params.minDeposit1) =
            LiquidityAmounts.getAmountsForLiquidity(
                sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(lowerTick),
                TickMath.getSqrtRatioAtTick(upperTick),
                liquidity
            );

            params.mints[0] = PositionLiquidity({
                liquidity: liquidity,
                range: Range({lowerTick: lowerTick, upperTick: upperTick})
            });

            // #endregion mint

            vm.prank(arrakisStandardManager);
            IPancakeSwapV3StandardModule(module).rebalance(params);
            // #endregion let's do a rebalance.
        }

        // #region withdraw.

        uint256 balance0 = token0.balanceOf(owner);
        uint256 balance1 = token1.balanceOf(owner);

        vm.startPrank(owner);

        IArrakisMetaVaultPrivate(vault).withdraw(BASE, owner);

        vm.stopPrank();

        assertEq(
            token0.balanceOf(owner) - balance0, (amount0 / 2) - 1
        );
        assertEq(token1.balanceOf(owner) - balance1, amount1 - 1);

        // #endregion withdraw.
    }

    function test_claim_rewards() public {
        uint256 amount0;
        uint256 amount1;
        address module;

        {
            address depositor =
                vm.addr(uint256(keccak256(abi.encode("Depositor"))));

            {
                address[] memory depositors = new address[](1);
                depositors[0] = depositor;

                vm.prank(owner);
                IArrakisMetaVaultPrivate(vault).whitelistDepositors(
                    depositors
                );
            }

            amount0 = 10 * 10 ** 18;
            amount1 = 40_000 * 10 ** 18;

            deal(WETH, depositor, amount0);
            deal(BUSD, depositor, amount1);

            // #region get module address.

            module = address(IArrakisMetaVault(vault).module());

            // #endregion get module address.

            // #region fund.

            vm.startPrank(depositor);

            IERC20Metadata(IArrakisMetaVault(vault).token0())
                .safeApprove(module, amount0);
            IERC20Metadata(IArrakisMetaVault(vault).token1())
                .safeApprove(module, amount1);

            IArrakisMetaVaultPrivate(vault).deposit(amount0, amount1);

            vm.stopPrank();

            // #endregion fund.
        }

        // #region rewards.

        uint256 cakeBalance =
            IERC20Metadata(CAKE).balanceOf(distributor);
        uint256 busdBalance =
            IERC20Metadata(BUSD).balanceOf(distributor);

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

        vm.prank(distributorOwner);
        IAccessControl(distributor).grantRole(
            MERKLE_ROOT_SETTER, address(this)
        );

        IPancakeDistributorExtension(distributor).setMerkleTree(
            root, keccak256(abi.encode("IpfsHash"))
        );

        vm.warp(
            IPancakeDistributorExtension(distributor)
                .endOfDisputePeriod() + 1
        );

        // #endregion rewards.

        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));

        assertEq(IERC20Metadata(CAKE).balanceOf(receiver), 0);

        vm.prank(owner);
        IPancakeSwapV3StandardModule(module).claimRewards(
            params, escrowed, receiver
        );

        uint256 managerFeePIPS =
            IArrakisLPModule(module).managerFeePIPS();

        address rewardReceiver =
            IPancakeSwapV3StandardModule(module).rewardReceiver();

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
    }

    function test_manager_claim_rewards() public {
        uint256 amount0;
        uint256 amount1;
        address module;

        {
            address depositor =
                vm.addr(uint256(keccak256(abi.encode("Depositor"))));

            {
                address[] memory depositors = new address[](1);
                depositors[0] = depositor;

                vm.prank(owner);
                IArrakisMetaVaultPrivate(vault).whitelistDepositors(
                    depositors
                );
            }

            amount0 = 10 * 10 ** 18;
            amount1 = 40_000 * 10 ** 18;

            deal(WETH, depositor, amount0);
            deal(BUSD, depositor, amount1);

            // #region get module address.

            module = address(IArrakisMetaVault(vault).module());

            // #endregion get module address.

            // #region fund.

            vm.startPrank(depositor);

            IERC20Metadata(IArrakisMetaVault(vault).token0())
                .safeApprove(module, amount0);
            IERC20Metadata(IArrakisMetaVault(vault).token1())
                .safeApprove(module, amount1);

            IArrakisMetaVaultPrivate(vault).deposit(amount0, amount1);

            vm.stopPrank();

            // #endregion fund.
        }

        // #region rewards.

        uint256 cakeBalance =
            IERC20Metadata(CAKE).balanceOf(distributor);
        uint256 busdBalance =
            IERC20Metadata(BUSD).balanceOf(distributor);

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

        vm.prank(distributorOwner);
        IAccessControl(distributor).grantRole(
            MERKLE_ROOT_SETTER, address(this)
        );

        IPancakeDistributorExtension(distributor).setMerkleTree(
            root, keccak256(abi.encode("IpfsHash"))
        );

        vm.warp(
            IPancakeDistributorExtension(distributor)
                .endOfDisputePeriod() + 1
        );

        // #endregion rewards.

        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));

        uint256 managerFeePIPS =
            IArrakisLPModule(module).managerFeePIPS();

        assertEq(IERC20Metadata(CAKE).balanceOf(receiver), 0);

        // #region claim manager rewards.

        vm.prank(arrakisStandardManager);
        IPancakeSwapV3StandardModule(module).claimManagerRewards(
            params
        );

        // #endregion claim manager rewards.

        // #region claim rewards.

        params = new IPancakeDistributor.ClaimParams[](0);
        escrowed = new IPancakeDistributor.ClaimEscrowed[](1);
        escrowed[0].token = CAKE;
        escrowed[0].amount = FullMath.mulDiv(
            1_000_000_000_000_000_000, managerFeePIPS, PIPS
        );

        vm.prank(owner);
        IPancakeSwapV3StandardModule(module).claimRewards(
            params, escrowed, receiver
        );

        // #endregion claim rewards.

        address rewardReceiver =
            IPancakeSwapV3StandardModule(module).rewardReceiver();

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
    }

    // #endregion tests.

    // #region swap.

    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin
    ) external {
        uint256 balanceOut =
            IERC20Metadata(tokenOut).balanceOf(msg.sender);
        deal(tokenOut, msg.sender, amountOutMin + balanceOut);

        IERC20Metadata(tokenIn).safeTransferFrom(
            msg.sender, address(this), amountIn
        );
    }

    // #endregion swap.

    // #region internal helper functions.

    function _createModuleAndWhitelist() internal {
        // #region create a uniswap v3 module.

        address implementation = address(
            new PancakeSwapV3StandardModulePrivate(
                guardian, pancakeSwapV3Factory, distributor
            )
        );

        pancakeSwapStandardModuleBeacon =
            address(new UpgradeableBeacon(implementation));

        UpgradeableBeacon(pancakeSwapStandardModuleBeacon)
            .transferOwnership(arrakisTimeLock);

        address[] memory beacons = new address[](1);
        beacons[0] = address(pancakeSwapStandardModuleBeacon);

        vm.prank(privateRegistryOwner);
        IModuleRegistry(privateRegistry).whitelistBeacons(beacons);

        // #endregion create a uniswap v3 module.
    }

    // #endregion internal helper functions.
}
