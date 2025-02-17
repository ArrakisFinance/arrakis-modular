// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

// #region foundry.
import {TestWrapper} from "../utils/TestWrapper.sol";
import {console} from "forge-std/console.sol";
// #endregion foundry.

import {VelodromeStandardModulePrivate} from
    "../../src/modules/VelodromeStandardModulePrivate.sol";
import {
    BASE,
    PIPS,
    TEN_PERCENT,
    NATIVE_COIN
} from "../../src/constants/CArrakis.sol";
import {
    RebalanceParams,
    ModifyPosition,
    SwapPayload
} from "../../src/structs/SUniswapV3.sol";
import {IArrakisMetaVault} from
    "../../src/interfaces/IArrakisMetaVault.sol";

// #region interfaces.
import {IVelodromeStandardModulePrivate} from
    "../../src/interfaces/IVelodromeStandardModulePrivate.sol";
import {IArrakisLPModule} from
    "../../src/interfaces/IArrakisLPModule.sol";
import {IArrakisMetaVaultFactory} from
    "../../src/interfaces/IArrakisMetaVaultFactory.sol";
import {IArrakisStandardManager} from
    "../../src/interfaces/IArrakisStandardManager.sol";
import {IArrakisLPModulePrivate} from
    "../../src/interfaces/IArrakisLPModulePrivate.sol";
import {IGuardian} from "../../src/interfaces/IGuardian.sol";
import {IModuleRegistry} from
    "../../src/interfaces/IModuleRegistry.sol";
import {IPauser} from "../../src/interfaces/IPauser.sol";
import {IOracleWrapper} from "../../src/interfaces/IOracleWrapper.sol";
import {INonfungiblePositionManager} from
    "../../src/interfaces/INonfungiblePositionManager.sol";
import {IVoter} from "../../src/interfaces/IVoter.sol";
import {IUniswapV3Factory} from
    "../../src/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "../../src/interfaces/IUniswapV3Pool.sol";
import {IOwnable} from "../../src/interfaces/IOwnable.sol";
import {IUniswapV3SwapCallback} from
    "../../src/interfaces/IUniswapV3SwapCallback.sol";
// #endregion interfaces.

// #region openzeppelin.
import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {UpgradeableBeacon} from
    "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {BeaconProxy} from
    "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {PausableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
// #endregion openzeppelin.

// #region mocks.
import {OracleWrapper} from "./mocks/OracleWrapper.sol";
import {MetaVaultMock} from "./mocks/MetaVaultMock.sol";
// #endregion mocks.

import {TickMath} from "@v3-lib-0.8/contracts/TickMath.sol";
import {FullMath} from "@v3-lib-0.8/contracts/FullMath.sol";

contract VelodromeStandardModulePrivateTest is
    TestWrapper,
    IUniswapV3SwapCallback
{
    using SafeERC20 for IERC20Metadata;

    // #region constant properties.
    address public constant WETH =
        0x4200000000000000000000000000000000000006;
    address public constant USDC =
        0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;
    address public constant VELO =
        0x9560e827aF36c94D2Ac33a39bCE1Fe78631088Db;
    // #endregion constant properties.

    // #region arrakis modular contracts.
    address public constant arrakisStandardManager =
        0x2e6E879648293e939aA68bA4c6c129A1Be733bDA;
    address public constant arrakisStandardManagerOwner =
        0x8636600A864797Aa7ac8807A065C5d8BD9bA3Ccb;
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
        0x283824e5A6378EaB2695Be7d3cb0919186e37D7C;
    address public constant permit2 =
        0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address public constant weth =
        0x4200000000000000000000000000000000000006;
    // #endregion arrakis modular contracts.

    address public owner;

    address public module;
    address public vault;
    address public executor;
    address public stratAnnouncer;
    address public beacon;

    // #region velodrome.
    address public nonfungiblePositionManager =
        0x416b433906b1B72FA758e166e239c43d68dC6F29;
    address public clfactory =
        0xCc0bDDB707055e04e497aB22a59c2aF4391cd12F;
    address public voter = 0x41C914ee0c7E1A5edCD0295623e6dC557B5aBf3C;
    address public velo = 0x9560e827aF36c94D2Ac33a39bCE1Fe78631088Db;
    // #endregion velodrome.

    // #region mocks.
    address public oracle;
    // #endregion mocks.

    // #region vault info.
    uint256 public init0;
    uint256 public init1;
    uint24 public maxSlippage;
    uint24 public maxDeviation;
    uint256 public cooldownPeriod;
    uint160 public sqrtPriceX96;
    address public veloReceiver;
    // #endregion vault info.

    IERC20Metadata public token0;
    IERC20Metadata public token1;

    function setUp() public {
        // #region reset fork.
        /// @dev op chain.

        _reset(vm.envString("OP_RPC_URL"), 131_874_003);

        // #endregion reset fork.

        // #region setup.
        owner = vm.addr(uint256(keccak256(abi.encode("Owner"))));
        executor = vm.addr(uint256(keccak256(abi.encode("EXECUTOR"))));
        stratAnnouncer =
            vm.addr(uint256(keccak256(abi.encode("STRAT_ANNOUNCER"))));
        veloReceiver =
            vm.addr(uint256(keccak256(abi.encode("VELO_RECEIVER"))));
        // #endregion setup.

        // #region create an oracle.
        oracle = address(new OracleWrapper());
        // #endregion create an oracle.

        OracleWrapper(oracle).setPrice0(382_450_128_503_243);
        OracleWrapper(oracle).setPrice1(2614e6);

        _setup();

        maxSlippage = TEN_PERCENT;
        maxDeviation = TEN_PERCENT;
        cooldownPeriod = 60 seconds;

        // #region create a vault with velodrome module.

        bytes memory moduleCreationPayload = abi.encodeWithSelector(
            IVelodromeStandardModulePrivate.initialize.selector,
            IOracleWrapper(oracle),
            maxSlippage,
            veloReceiver,
            100
        );

        bytes memory initManagementPayload = abi.encode(
            IOracleWrapper(oracle),
            maxDeviation,
            cooldownPeriod,
            executor,
            stratAnnouncer,
            maxSlippage
        );

        bytes32 salt = keccak256(
            abi.encode("Salt WETH/USDC Velo vault Private Test")
        );

        vault = IArrakisMetaVaultFactory(factory).deployPrivateVault(
            salt,
            USDC,
            WETH,
            owner,
            beacon,
            moduleCreationPayload,
            initManagementPayload
        );

        // #endregion create a vault with velodrome module.

        module = address(IArrakisMetaVault(vault).module());
    }

    // #region uniswap callback.

    function uniswapV3SwapCallback(
        int256 amount0_,
        int256 amount1_,
        bytes calldata
    ) external {
        if (amount0_ > 0) {
            uint256 balance =
                IERC20Metadata(USDC).balanceOf(msg.sender);
            deal(USDC, msg.sender, balance + uint256(amount0_));
        }
        if (amount1_ > 0) {
            uint256 balance =
                IERC20Metadata(WETH).balanceOf(msg.sender);
            deal(WETH, msg.sender, balance + uint256(amount1_));
        }
    }

    // #endregion uniswap callback.

    // #region test pause and unpause.

    function test_pause_when_already_paused() public {
        vm.prank(pauser);
        VelodromeStandardModulePrivate(module).pause();

        vm.expectRevert("Pausable: paused");
        VelodromeStandardModulePrivate(module).pause();
    }

    function test_pause_only_guardian() public {
        address notGuardian =
            vm.addr(uint256(keccak256(abi.encode("Not Guardian"))));

        vm.prank(notGuardian);
        vm.expectRevert(IArrakisLPModule.OnlyGuardian.selector);
        VelodromeStandardModulePrivate(module).pause();
    }

    function test_pause() public {
        vm.prank(pauser);
        VelodromeStandardModulePrivate(module).pause();

        assertTrue(VelodromeStandardModulePrivate(module).paused());
    }

    function test_unpause_when_already_unpaused() public {
        vm.prank(pauser);
        vm.expectRevert("Pausable: not paused");
        VelodromeStandardModulePrivate(module).unpause();
    }

    function test_unpause_only_guardian() public {
        vm.prank(pauser);
        VelodromeStandardModulePrivate(module).pause();

        address notGuardian =
            vm.addr(uint256(keccak256(abi.encode("Not Guardian"))));

        vm.prank(notGuardian);
        vm.expectRevert(IArrakisLPModule.OnlyGuardian.selector);
        VelodromeStandardModulePrivate(module).unpause();
    }

    function test_unpause() public {
        vm.prank(pauser);
        VelodromeStandardModulePrivate(module).pause();

        assertTrue(VelodromeStandardModulePrivate(module).paused());

        vm.prank(pauser);
        VelodromeStandardModulePrivate(module).unpause();

        assertFalse(VelodromeStandardModulePrivate(module).paused());
    }

    // #endregion test pause and unpause.

    // #region constructor.

    function test_constructor_nftPositionManager_is_address_zero()
        public
    {
        vm.expectRevert(IArrakisLPModule.AddressZero.selector);
        new VelodromeStandardModulePrivate(
            address(0), clfactory, voter, guardian
        );
    }

    function test_constructor_factory_is_address_zero() public {
        vm.expectRevert(IArrakisLPModule.AddressZero.selector);
        new VelodromeStandardModulePrivate(
            nonfungiblePositionManager, address(0), voter, guardian
        );
    }

    function test_constructor_voter_is_address_zero() public {
        vm.expectRevert(IArrakisLPModule.AddressZero.selector);
        new VelodromeStandardModulePrivate(
            nonfungiblePositionManager, factory, address(0), guardian
        );
    }

    function test_constructor_guardian_is_address_zero() public {
        vm.expectRevert(IArrakisLPModule.AddressZero.selector);
        new VelodromeStandardModulePrivate(
            nonfungiblePositionManager, factory, voter, address(0)
        );
    }

    // #endregion constructor.

    // #region initialize.

    function test_initialize_oracle_address_zero() public {
        address a = vm.addr(124_343); // Vault address

        bytes memory moduleCreationPayload = abi.encodeWithSelector(
            IVelodromeStandardModulePrivate.initialize.selector,
            IOracleWrapper(address(0)),
            maxSlippage,
            veloReceiver,
            100,
            a
        );

        vm.expectRevert(IArrakisLPModule.AddressZero.selector);
        new BeaconProxy(beacon, moduleCreationPayload);
    }

    function test_initialize_metaVault_address_zero() public {
        bytes memory moduleCreationPayload = abi.encodeWithSelector(
            IVelodromeStandardModulePrivate.initialize.selector,
            IOracleWrapper(oracle),
            maxSlippage,
            veloReceiver,
            100,
            address(0)
        );

        vm.expectRevert(IArrakisLPModule.AddressZero.selector);
        new BeaconProxy(beacon, moduleCreationPayload);
    }

    function test_initialize_veloReceiver_address_zero() public {
        address a = vm.addr(124_343); // Vault address

        bytes memory moduleCreationPayload = abi.encodeWithSelector(
            IVelodromeStandardModulePrivate.initialize.selector,
            IOracleWrapper(oracle),
            maxSlippage,
            address(0),
            100,
            a
        );

        vm.expectRevert(IArrakisLPModule.AddressZero.selector);
        new BeaconProxy(beacon, moduleCreationPayload);
    }

    function test_initialize_maxSlippage_gt_ten_percent() public {
        address a = vm.addr(124_343); // Vault address

        bytes memory moduleCreationPayload = abi.encodeWithSelector(
            IVelodromeStandardModulePrivate.initialize.selector,
            IOracleWrapper(oracle),
            TEN_PERCENT + 1,
            veloReceiver,
            100,
            a
        );

        vm.expectRevert(
            IVelodromeStandardModulePrivate
                .MaxSlippageGtTenPercent
                .selector
        );
        new BeaconProxy(beacon, moduleCreationPayload);
    }

    function test_initialize_no_native_coin() public {
        address a = address(new MetaVaultMock());

        MetaVaultMock(a).setTokens(USDC, NATIVE_COIN);

        bytes memory moduleCreationPayload = abi.encodeWithSelector(
            IVelodromeStandardModulePrivate.initialize.selector,
            IOracleWrapper(oracle),
            maxSlippage,
            veloReceiver,
            10,
            a
        );

        vm.expectRevert(
            IVelodromeStandardModulePrivate
                .NativeCoinNotSupported
                .selector
        );
        new BeaconProxy(beacon, moduleCreationPayload);
    }

    function test_initialize_pool_not_found() public {
        address a = address(new MetaVaultMock());

        MetaVaultMock(a).setTokens(WETH, USDC);

        bytes memory moduleCreationPayload = abi.encodeWithSelector(
            IVelodromeStandardModulePrivate.initialize.selector,
            IOracleWrapper(oracle),
            maxSlippage,
            veloReceiver,
            10,
            a
        );

        vm.expectRevert(
            IVelodromeStandardModulePrivate.PoolNotFound.selector
        );
        new BeaconProxy(beacon, moduleCreationPayload);
    }

    function test_initialize_velo_not_supported() public {
        address a = address(new MetaVaultMock());

        MetaVaultMock(a).setTokens(USDC, VELO);

        bytes memory moduleCreationPayload = abi.encodeWithSelector(
            IVelodromeStandardModulePrivate.initialize.selector,
            IOracleWrapper(oracle),
            maxSlippage,
            veloReceiver,
            10,
            a
        );

        vm.expectRevert(
            IVelodromeStandardModulePrivate
                .VELOTokenNotSupported
                .selector
        );
        new BeaconProxy(beacon, moduleCreationPayload);
    }

    function test_initialize_gauge_killed() public {
        address a = address(new MetaVaultMock());

        MetaVaultMock(a).setTokens(WETH, USDC);

        bytes memory moduleCreationPayload = abi.encodeWithSelector(
            IVelodromeStandardModulePrivate.initialize.selector,
            IOracleWrapper(oracle),
            maxSlippage,
            veloReceiver,
            100,
            a
        );

        // #region kill gauge.

        address pool =
            IUniswapV3Factory(clfactory).getPool(WETH, USDC, 100);

        address gauge = IVoter(voter).gauges(pool);

        vm.prank(IVoter(voter).emergencyCouncil());
        IVoter(voter).killGauge(gauge);

        // #endregion kill gauge.

        vm.expectRevert(
            IVelodromeStandardModulePrivate.GaugeKilled.selector
        );
        address beacon =
            address(new BeaconProxy(beacon, moduleCreationPayload));
    }

    function test_initialize() public {
        address a = address(new MetaVaultMock());

        MetaVaultMock(a).setTokens(WETH, USDC);

        bytes memory moduleCreationPayload = abi.encodeWithSelector(
            IVelodromeStandardModulePrivate.initialize.selector,
            IOracleWrapper(oracle),
            maxSlippage,
            veloReceiver,
            100,
            a
        );

        address pool =
            IUniswapV3Factory(clfactory).getPool(WETH, USDC, 100);

        address beacon =
            address(new BeaconProxy(beacon, moduleCreationPayload));

        assertEq(address(IArrakisLPModule(beacon).token0()), WETH);
        assertEq(address(IArrakisLPModule(beacon).token1()), USDC);
        assertEq(address(IArrakisLPModule(beacon).metaVault()), a);
        assertEq(
            IVelodromeStandardModulePrivate(beacon).maxSlippage(),
            maxSlippage
        );
        assertEq(
            address(
                IVelodromeStandardModulePrivate(beacon).veloReceiver()
            ),
            veloReceiver
        );
        assertEq(
            address(IVelodromeStandardModulePrivate(beacon).pool()),
            pool
        );
    }

    // #endregion test initialize.

    // #region initialize position.

    function test_initialize_position() public {
        IArrakisLPModule(module).initializePosition("");
    }

    // #endregion initialize position.

    // #region test approve.

    function test_approve_not_vault_owner() public {
        address spender =
            vm.addr(uint256(keccak256(abi.encode("Spender"))));
        uint256 amount0 = 1 ether;
        uint256 amount1 = 3850e6;

        vm.expectRevert(
            IVelodromeStandardModulePrivate
                .OnlyMetaVaultOwner
                .selector
        );
        IVelodromeStandardModulePrivate(module).approve(
            spender, amount0, amount1
        );
    }

    function test_approve() public {
        address spender =
            vm.addr(uint256(keccak256(abi.encode("Spender"))));
        uint256 amount0 = 2614e6;
        uint256 amount1 = 1 ether;

        vm.prank(owner);
        IVelodromeStandardModulePrivate(module).approve(
            spender, amount0, amount1
        );

        deal(USDC, module, amount0);
        deal(WETH, module, amount1);

        assertEq(IERC20Metadata(USDC).balanceOf(spender), 0);
        assertEq(IERC20Metadata(WETH).balanceOf(spender), 0);

        vm.startPrank(spender);

        IERC20Metadata(USDC).transferFrom(module, spender, amount0);
        IERC20Metadata(WETH).transferFrom(module, spender, amount1);

        vm.stopPrank();

        assertEq(IERC20Metadata(USDC).balanceOf(spender), amount0);
        assertEq(IERC20Metadata(WETH).balanceOf(spender), amount1);
    }

    // #endregion test approve.

    // #region test fund.

    function test_fund_only_meta_vault() public {
        address notMetaVault =
            vm.addr(uint256(keccak256(abi.encode("Not MetaVault"))));
        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));

        vm.prank(notMetaVault);
        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisLPModule.OnlyMetaVault.selector,
                notMetaVault,
                vault
            )
        );
        IArrakisLPModulePrivate(module).fund(
            depositor, 1 ether, 3850e6
        );
    }

    function test_fund_native_coin_not_supported() public {
        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));

        deal(vault, 1 ether);

        vm.prank(vault);
        vm.expectRevert(
            IVelodromeStandardModulePrivate
                .NativeCoinNotSupported
                .selector
        );

        IArrakisLPModulePrivate(module).fund{value: 1 ether}(
            depositor, 1 ether, 3850e6
        );
    }

    function test_fund_amounts_zero() public {
        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));

        vm.prank(vault);
        vm.expectRevert(
            IVelodromeStandardModulePrivate.AmountsZero.selector
        );

        IArrakisLPModulePrivate(module).fund(depositor, 0, 0);
    }

    function test_fund() public {
        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));

        deal(WETH, depositor, 1 ether);
        deal(USDC, depositor, 2614e6);

        assertEq(IERC20Metadata(WETH).balanceOf(module), 0);
        assertEq(IERC20Metadata(USDC).balanceOf(module), 0);

        vm.startPrank(depositor);
        IERC20Metadata(WETH).approve(module, 1 ether);
        IERC20Metadata(USDC).approve(module, 2614e6);
        vm.stopPrank();

        vm.prank(vault);
        IArrakisLPModulePrivate(module).fund(
            depositor, 2614e6, 1 ether
        );

        assertEq(IERC20Metadata(WETH).balanceOf(module), 1 ether);
        assertEq(IERC20Metadata(USDC).balanceOf(module), 2614e6);
    }

    // #endregion test fund.

    // #region test withdraw.

    function test_withdraw_only_meta_vault() public {
        address notMetaVault =
            vm.addr(uint256(keccak256(abi.encode("Not MetaVault"))));
        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));

        vm.prank(notMetaVault);
        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisLPModule.OnlyMetaVault.selector,
                notMetaVault,
                vault
            )
        );
        IArrakisLPModule(module).withdraw(receiver, BASE);
    }

    function test_withdraw_receiver_address_zero() public {
        vm.prank(vault);
        vm.expectRevert(IArrakisLPModule.AddressZero.selector);
        IArrakisLPModule(module).withdraw(address(0), BASE);
    }

    function test_withdraw_receiver_proportion_zero() public {
        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));

        vm.prank(vault);
        vm.expectRevert(IArrakisLPModule.ProportionZero.selector);
        IArrakisLPModule(module).withdraw(receiver, 0);
    }

    function test_withdraw_receiver_proportion_gt_base() public {
        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));

        vm.prank(vault);
        vm.expectRevert(IArrakisLPModule.ProportionGtBASE.selector);
        IArrakisLPModule(module).withdraw(receiver, BASE + 1);
    }

    function test_withdraw() public {
        // #region deposit.

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));

        uint256 amount0 = 0;
        uint256 amount1 = 2 ether;

        deal(WETH, depositor, amount1);

        // #region approve the module.

        vm.startPrank(depositor);
        IERC20Metadata(WETH).approve(module, amount1);
        vm.stopPrank();

        // #endregion approve the module.

        vm.prank(address(vault));
        IArrakisLPModulePrivate(module).fund(
            depositor, amount0, amount1
        );

        // #endregion deposit.

        // #region rebalance with swap.

        // Zero for one swap.

        ModifyPosition[] memory modifyPositions =
            new ModifyPosition[](0);
        SwapPayload memory swapPayload;

        swapPayload.amountIn = 1 ether;
        swapPayload.expectedMinReturn = 2610e6;
        swapPayload.router = address(this);
        swapPayload.payload =
            abi.encodeWithSelector(this.swap.selector);
        swapPayload.zeroForOne = false;

        int24 tickSpacing = 100;

        (, int24 tick,,,,) = IUniswapV3Pool(
            IUniswapV3Factory(clfactory).getPool(
                USDC, WETH, tickSpacing
            )
        ).slot0();

        INonfungiblePositionManager.MintParams[] memory mintParams =
            new INonfungiblePositionManager.MintParams[](1);
        mintParams[0] = INonfungiblePositionManager.MintParams({
            token0: USDC,
            token1: WETH,
            tickSpacing: tickSpacing,
            tickLower: int24(tick - (tick % 100) - 100),
            tickUpper: int24(tick - (tick % 100) + 100),
            amount0Desired: 2614e6,
            amount1Desired: 1 ether,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(module),
            deadline: type(uint256).max,
            sqrtPriceX96: 0
        });

        vm.prank(arrakisStandardManager);
        IVelodromeStandardModulePrivate(module).rebalance(
            RebalanceParams({
                decreasePositions: modifyPositions,
                increasePositions: modifyPositions,
                swapPayload: swapPayload,
                mintParams: mintParams,
                minBurn0: 0,
                minBurn1: 0,
                minDeposit0: 0,
                minDeposit1: 0
            })
        );

        // #endregion rebalance.

        // #region withdraw.

        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));

        vm.prank(vault);
        IArrakisLPModule(module).withdraw(receiver, BASE);

        // #endregion withdraw.
    }

    // #endregion test withdraw.

    // #region test claimRewards.

    function test_claim_rewards_only_meta_vault_owner() public {
        address notMetaVaultOwner = vm.addr(
            uint256(keccak256(abi.encode("Not MetaVault Owner")))
        );
        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));

        vm.prank(notMetaVaultOwner);
        vm.expectRevert(
            IVelodromeStandardModulePrivate
                .OnlyMetaVaultOwner
                .selector
        );
        IVelodromeStandardModulePrivate(module).claimRewards(receiver);
    }

    function test_claim_rewards_receiver_address_zero() public {
        vm.prank(owner);
        vm.expectRevert(IArrakisLPModule.AddressZero.selector);
        IVelodromeStandardModulePrivate(module).claimRewards(
            address(0)
        );
    }

    function test_claim_rewards() public {
        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));

        uint256 amount0 = 2614e6;
        uint256 amount1 = 1 ether;

        deal(USDC, depositor, amount0);
        deal(WETH, depositor, amount1);

        // #region approve the module.

        vm.startPrank(depositor);
        IERC20Metadata(USDC).approve(module, amount0);
        IERC20Metadata(WETH).approve(module, amount1);
        vm.stopPrank();

        // #endregion approve the module.

        // #region deposit.

        vm.prank(address(vault));
        IArrakisLPModulePrivate(module).fund(
            depositor, amount0, amount1
        );

        // #endregion deposit.

        // #region rebalance.

        ModifyPosition[] memory modifyPositions =
            new ModifyPosition[](0);
        SwapPayload memory swapPayload;

        int24 tickSpacing = 100;

        (, int24 tick,,,,) = IUniswapV3Pool(
            IUniswapV3Factory(clfactory).getPool(
                USDC, WETH, tickSpacing
            )
        ).slot0();

        INonfungiblePositionManager.MintParams[] memory mintParams =
            new INonfungiblePositionManager.MintParams[](1);
        mintParams[0] = INonfungiblePositionManager.MintParams({
            token0: USDC,
            token1: WETH,
            tickSpacing: tickSpacing,
            tickLower: int24(tick - (tick % 100) - 100),
            tickUpper: int24(tick - (tick % 100) + 100),
            amount0Desired: 2614e6,
            amount1Desired: 1 ether,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(module),
            deadline: type(uint256).max,
            sqrtPriceX96: 0
        });

        vm.prank(arrakisStandardManager);
        IVelodromeStandardModulePrivate(module).rebalance(
            RebalanceParams({
                decreasePositions: modifyPositions,
                increasePositions: modifyPositions,
                swapPayload: swapPayload,
                mintParams: mintParams,
                minBurn0: 0,
                minBurn1: 0,
                minDeposit0: 0,
                minDeposit1: 0
            })
        );

        // #endregion rebalance.

        uint256 blockNumber = block.number;
        uint256 timestamp = block.timestamp;

        vm.warp(timestamp + 100);
        vm.roll(blockNumber + 100);

        // #region do swap.

        address recipient =
            vm.addr(uint256(keccak256(abi.encode("Recipient"))));
        bool zeroForOne = false;
        int256 amountSpecified = 0.5 ether;

        IUniswapV3Pool pool = IUniswapV3Pool(
            IUniswapV3Factory(clfactory).getPool(
                USDC, WETH, tickSpacing
            )
        );

        assertEq(IERC20Metadata(USDC).balanceOf(recipient), 0);

        pool.swap(
            recipient,
            zeroForOne,
            amountSpecified,
            TickMath.MAX_SQRT_RATIO - 1,
            ""
        );

        assertGt(IERC20Metadata(USDC).balanceOf(recipient), 0);

        // #endregion do swap.

        blockNumber = block.number;
        timestamp = block.timestamp;

        vm.warp(timestamp + 100);
        vm.roll(blockNumber + 100);

        // #region claim rewards.

        assertEq(IERC20Metadata(VELO).balanceOf(owner), 0);

        vm.prank(owner);
        IVelodromeStandardModulePrivate(module).claimRewards(owner);

        assertGt(IERC20Metadata(VELO).balanceOf(owner), 0);

        // #endregion claim rewards.
    }

    // #endregion test claimRewards.

    // #region test set receiver.

    function test_set_receiver_only_manager_owner() public {
        address notManagerOwner = vm.addr(
            uint256(keccak256(abi.encode("Not Manager Owner")))
        );
        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));

        vm.prank(notManagerOwner);
        vm.expectRevert(
            IVelodromeStandardModulePrivate.OnlyManagerOwner.selector
        );
        IVelodromeStandardModulePrivate(module).setReceiver(receiver);
    }

    function test_set_receiver_same_receiver() public {
        vm.prank(arrakisStandardManagerOwner);
        vm.expectRevert(
            IVelodromeStandardModulePrivate.SameReceiver.selector
        );
        IVelodromeStandardModulePrivate(module).setReceiver(
            veloReceiver
        );
    }

    function test_set_receiver_receiver_address_zero() public {
        vm.prank(arrakisStandardManagerOwner);
        vm.expectRevert(IArrakisLPModule.AddressZero.selector);
        IVelodromeStandardModulePrivate(module).setReceiver(
            address(0)
        );
    }

    function test_set_receiver() public {
        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));

        assertEq(
            IVelodromeStandardModulePrivate(module).veloReceiver(),
            veloReceiver
        );

        vm.prank(arrakisStandardManagerOwner);
        IVelodromeStandardModulePrivate(module).setReceiver(receiver);

        assertEq(
            address(
                IVelodromeStandardModulePrivate(module).veloReceiver()
            ),
            receiver
        );
    }

    // #endregion test set receiver.

    // #region test claimManager.

    function test_claim_manager() public {
        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));

        uint256 amount0 = 2614e6;
        uint256 amount1 = 1 ether;

        deal(USDC, depositor, amount0);
        deal(WETH, depositor, amount1);

        // #region approve the module.

        vm.startPrank(depositor);
        IERC20Metadata(USDC).approve(module, amount0);
        IERC20Metadata(WETH).approve(module, amount1);
        vm.stopPrank();

        // #endregion approve the module.

        // #region deposit.

        vm.prank(address(vault));
        IArrakisLPModulePrivate(module).fund(
            depositor, amount0, amount1
        );

        // #endregion deposit.

        // #region rebalance.

        ModifyPosition[] memory modifyPositions =
            new ModifyPosition[](0);
        SwapPayload memory swapPayload;

        int24 tickSpacing = 100;

        (, int24 tick,,,,) = IUniswapV3Pool(
            IUniswapV3Factory(clfactory).getPool(
                USDC, WETH, tickSpacing
            )
        ).slot0();

        INonfungiblePositionManager.MintParams[] memory mintParams =
            new INonfungiblePositionManager.MintParams[](1);
        mintParams[0] = INonfungiblePositionManager.MintParams({
            token0: USDC,
            token1: WETH,
            tickSpacing: tickSpacing,
            tickLower: int24(tick - (tick % 100) - 100),
            tickUpper: int24(tick - (tick % 100) + 100),
            amount0Desired: 2614e6,
            amount1Desired: 1 ether,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(module),
            deadline: type(uint256).max,
            sqrtPriceX96: 0
        });

        vm.prank(arrakisStandardManager);
        IVelodromeStandardModulePrivate(module).rebalance(
            RebalanceParams({
                decreasePositions: modifyPositions,
                increasePositions: modifyPositions,
                swapPayload: swapPayload,
                mintParams: mintParams,
                minBurn0: 0,
                minBurn1: 0,
                minDeposit0: 0,
                minDeposit1: 0
            })
        );

        // #endregion rebalance.

        uint256 blockNumber = block.number;
        uint256 timestamp = block.timestamp;

        vm.warp(timestamp + 100);
        vm.roll(blockNumber + 100);

        // #region do swap.

        address recipient =
            vm.addr(uint256(keccak256(abi.encode("Recipient"))));
        bool zeroForOne = false;
        int256 amountSpecified = 0.5 ether;

        IUniswapV3Pool pool = IUniswapV3Pool(
            IUniswapV3Factory(clfactory).getPool(
                USDC, WETH, tickSpacing
            )
        );

        assertEq(IERC20Metadata(USDC).balanceOf(recipient), 0);

        pool.swap(
            recipient,
            zeroForOne,
            amountSpecified,
            TickMath.MAX_SQRT_RATIO - 1,
            ""
        );

        assertGt(IERC20Metadata(USDC).balanceOf(recipient), 0);

        // #endregion do swap.

        blockNumber = block.number;
        timestamp = block.timestamp;

        vm.warp(timestamp + 100);
        vm.roll(blockNumber + 100);

        // #region claim rewards.

        assertEq(IERC20Metadata(VELO).balanceOf(owner), 0);

        vm.prank(owner);
        IVelodromeStandardModulePrivate(module).claimRewards(owner);

        assertGt(IERC20Metadata(VELO).balanceOf(owner), 0);

        // #endregion claim rewards.

        // #region claim manager rewards.

        assertEq(IERC20Metadata(VELO).balanceOf(veloReceiver), 0);

        IVelodromeStandardModulePrivate(module).claimManager();

        assertGt(IERC20Metadata(VELO).balanceOf(veloReceiver), 0);

        // #endregion claim manager rewards.
    }

    // #endregion test claimManager.

    // #region test setManagerFeePIPS.

    function test_set_manager_fee_pips_only_manager() public {
        address notManager =
            vm.addr(uint256(keccak256(abi.encode("Not Manager"))));

        vm.prank(notManager);
        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisLPModule.OnlyManager.selector,
                notManager,
                arrakisStandardManager
            )
        );
        IArrakisLPModule(module).setManagerFeePIPS(10_002);
    }

    function test_set_manager_fee_pips_same_manager_fee() public {
        vm.prank(arrakisStandardManager);
        vm.expectRevert(IArrakisLPModule.SameManagerFee.selector);
        IArrakisLPModule(module).setManagerFeePIPS(10_000);
    }

    function test_set_manager_fee_new_gt_pips() public {
        vm.prank(arrakisStandardManager);
        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisLPModule.NewFeesGtPIPS.selector, PIPS + 1
            )
        );
        IArrakisLPModule(module).setManagerFeePIPS(PIPS + 1);
    }

    // #endregion test setManagerFeePIPS.

    // #region test rebalance.

    function test_rebalance_with_swap_zero_for_one() public {
        // #region deposit.

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));

        uint256 amount0 = 0;
        uint256 amount1 = 2 ether;

        deal(WETH, depositor, amount1);

        // #region approve the module.

        vm.startPrank(depositor);
        IERC20Metadata(WETH).approve(module, amount1);
        vm.stopPrank();

        // #endregion approve the module.

        vm.prank(address(vault));
        IArrakisLPModulePrivate(module).fund(
            depositor, amount0, amount1
        );

        // #endregion deposit.

        // #region rebalance with swap.

        // Zero for one swap.

        ModifyPosition[] memory modifyPositions =
            new ModifyPosition[](0);
        SwapPayload memory swapPayload;

        swapPayload.amountIn = 1 ether;
        swapPayload.expectedMinReturn = 2610e6;
        swapPayload.router = address(this);
        swapPayload.payload =
            abi.encodeWithSelector(this.swap.selector);
        swapPayload.zeroForOne = false;

        int24 tickSpacing = 100;

        (, int24 tick,,,,) = IUniswapV3Pool(
            IUniswapV3Factory(clfactory).getPool(
                USDC, WETH, tickSpacing
            )
        ).slot0();

        INonfungiblePositionManager.MintParams[] memory mintParams =
            new INonfungiblePositionManager.MintParams[](1);
        mintParams[0] = INonfungiblePositionManager.MintParams({
            token0: USDC,
            token1: WETH,
            tickSpacing: tickSpacing,
            tickLower: int24(tick - (tick % 100) - 100),
            tickUpper: int24(tick - (tick % 100) + 100),
            amount0Desired: 2614e6,
            amount1Desired: 1 ether,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(module),
            deadline: type(uint256).max,
            sqrtPriceX96: 0
        });

        vm.prank(arrakisStandardManager);
        IVelodromeStandardModulePrivate(module).rebalance(
            RebalanceParams({
                decreasePositions: modifyPositions,
                increasePositions: modifyPositions,
                swapPayload: swapPayload,
                mintParams: mintParams,
                minBurn0: 0,
                minBurn1: 0,
                minDeposit0: 0,
                minDeposit1: 0
            })
        );

        // #endregion rebalance.
    }

    function test_rebalance_with_swap_one_for_zero() public {
        // #region deposit.

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));

        uint256 amount0 = 2614e6 * 2;
        uint256 amount1 = 0;

        deal(USDC, depositor, amount0);

        // #region approve the module.

        vm.startPrank(depositor);
        IERC20Metadata(USDC).approve(module, amount0);
        vm.stopPrank();

        // #endregion approve the module.

        vm.prank(address(vault));
        IArrakisLPModulePrivate(module).fund(
            depositor, amount0, amount1
        );

        // #endregion deposit.

        // #region rebalance with swap.

        // Zero for one swap.

        ModifyPosition[] memory modifyPositions =
            new ModifyPosition[](0);
        SwapPayload memory swapPayload;

        swapPayload.amountIn = 2614e6;
        swapPayload.expectedMinReturn = 1 ether;
        swapPayload.router = address(this);
        swapPayload.payload =
            abi.encodeWithSelector(this.swapOneForZero.selector);
        swapPayload.zeroForOne = true;

        int24 tickSpacing = 100;

        (, int24 tick,,,,) = IUniswapV3Pool(
            IUniswapV3Factory(clfactory).getPool(
                USDC, WETH, tickSpacing
            )
        ).slot0();

        INonfungiblePositionManager.MintParams[] memory mintParams =
            new INonfungiblePositionManager.MintParams[](1);
        mintParams[0] = INonfungiblePositionManager.MintParams({
            token0: USDC,
            token1: WETH,
            tickSpacing: tickSpacing,
            tickLower: int24(tick - (tick % 100) - 100),
            tickUpper: int24(tick - (tick % 100) + 100),
            amount0Desired: 2614e6,
            amount1Desired: 1 ether,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(module),
            deadline: type(uint256).max,
            sqrtPriceX96: 0
        });

        vm.prank(arrakisStandardManager);
        IVelodromeStandardModulePrivate(module).rebalance(
            RebalanceParams({
                decreasePositions: modifyPositions,
                increasePositions: modifyPositions,
                swapPayload: swapPayload,
                mintParams: mintParams,
                minBurn0: 0,
                minBurn1: 0,
                minDeposit0: 0,
                minDeposit1: 0
            })
        );

        // #endregion rebalance.
    }

    function test_rebalance_expected_min_return_too_low_one_for_zero()
        public
    {
        // #region deposit.

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));

        uint256 amount0 = 0;
        uint256 amount1 = 2 ether;

        deal(WETH, depositor, amount1);

        // #region approve the module.

        vm.startPrank(depositor);
        IERC20Metadata(WETH).approve(module, amount1);
        vm.stopPrank();

        // #endregion approve the module.

        vm.prank(address(vault));
        IArrakisLPModulePrivate(module).fund(
            depositor, amount0, amount1
        );

        // #endregion deposit.

        // #region rebalance with swap.

        // Zero for one swap.

        ModifyPosition[] memory modifyPositions =
            new ModifyPosition[](0);
        SwapPayload memory swapPayload;

        swapPayload.amountIn = 1 ether;
        swapPayload.expectedMinReturn = 2010e6;
        swapPayload.router = address(this);
        swapPayload.payload =
            abi.encodeWithSelector(this.swap.selector);
        swapPayload.zeroForOne = false;

        int24 tickSpacing = 100;

        (, int24 tick,,,,) = IUniswapV3Pool(
            IUniswapV3Factory(clfactory).getPool(
                USDC, WETH, tickSpacing
            )
        ).slot0();

        INonfungiblePositionManager.MintParams[] memory mintParams =
            new INonfungiblePositionManager.MintParams[](1);
        mintParams[0] = INonfungiblePositionManager.MintParams({
            token0: USDC,
            token1: WETH,
            tickSpacing: tickSpacing,
            tickLower: int24(tick - (tick % 100) - 100),
            tickUpper: int24(tick - (tick % 100) + 100),
            amount0Desired: 2614e6,
            amount1Desired: 1 ether,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(module),
            deadline: type(uint256).max,
            sqrtPriceX96: 0
        });

        vm.prank(arrakisStandardManager);
        vm.expectRevert(
            IVelodromeStandardModulePrivate
                .ExpectedMinReturnTooLow
                .selector
        );
        IVelodromeStandardModulePrivate(module).rebalance(
            RebalanceParams({
                decreasePositions: modifyPositions,
                increasePositions: modifyPositions,
                swapPayload: swapPayload,
                mintParams: mintParams,
                minBurn0: 0,
                minBurn1: 0,
                minDeposit0: 0,
                minDeposit1: 0
            })
        );

        // #endregion rebalance.
    }

    function test_rebalance_expected_min_return_too_low() public {
        // #region deposit.

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));

        uint256 amount0 = 2614e6 * 2;
        uint256 amount1 = 0;

        deal(USDC, depositor, amount0);

        // #region approve the module.

        vm.startPrank(depositor);
        IERC20Metadata(USDC).approve(module, amount0);
        vm.stopPrank();

        // #endregion approve the module.

        vm.prank(address(vault));
        IArrakisLPModulePrivate(module).fund(
            depositor, amount0, amount1
        );

        // #endregion deposit.

        // #region rebalance with swap.

        // Zero for one swap.

        ModifyPosition[] memory modifyPositions =
            new ModifyPosition[](0);
        SwapPayload memory swapPayload;

        swapPayload.amountIn = 2614e6;
        swapPayload.expectedMinReturn = 0.5 ether;
        swapPayload.router = address(this);
        swapPayload.payload =
            abi.encodeWithSelector(this.swapOneForZero.selector);
        swapPayload.zeroForOne = true;

        int24 tickSpacing = 100;

        (, int24 tick,,,,) = IUniswapV3Pool(
            IUniswapV3Factory(clfactory).getPool(
                USDC, WETH, tickSpacing
            )
        ).slot0();

        INonfungiblePositionManager.MintParams[] memory mintParams =
            new INonfungiblePositionManager.MintParams[](1);
        mintParams[0] = INonfungiblePositionManager.MintParams({
            token0: USDC,
            token1: WETH,
            tickSpacing: tickSpacing,
            tickLower: int24(tick - (tick % 100) - 100),
            tickUpper: int24(tick - (tick % 100) + 100),
            amount0Desired: 2614e6,
            amount1Desired: 1 ether,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(module),
            deadline: type(uint256).max,
            sqrtPriceX96: 0
        });

        vm.prank(arrakisStandardManager);
        vm.expectRevert(
            IVelodromeStandardModulePrivate
                .ExpectedMinReturnTooLow
                .selector
        );
        IVelodromeStandardModulePrivate(module).rebalance(
            RebalanceParams({
                decreasePositions: modifyPositions,
                increasePositions: modifyPositions,
                swapPayload: swapPayload,
                mintParams: mintParams,
                minBurn0: 0,
                minBurn1: 0,
                minDeposit0: 0,
                minDeposit1: 0
            })
        );

        // #endregion rebalance.
    }

    function test_rebalance_with_swap_wrong_router() public {
        // #region deposit.

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));

        uint256 amount0 = 0;
        uint256 amount1 = 2 ether;

        deal(WETH, depositor, amount1);

        // #region approve the module.

        vm.startPrank(depositor);
        IERC20Metadata(WETH).approve(module, amount1);
        vm.stopPrank();

        // #endregion approve the module.

        vm.prank(address(vault));
        IArrakisLPModulePrivate(module).fund(
            depositor, amount0, amount1
        );

        // #endregion deposit.

        // #region rebalance with swap.

        // Zero for one swap.

        ModifyPosition[] memory modifyPositions =
            new ModifyPosition[](0);
        SwapPayload memory swapPayload;

        swapPayload.amountIn = 1 ether;
        swapPayload.expectedMinReturn = 2614e6;
        swapPayload.router = vault;
        swapPayload.payload =
            abi.encodeWithSelector(this.swap.selector);
        swapPayload.zeroForOne = false;

        int24 tickSpacing = 100;

        (, int24 tick,,,,) = IUniswapV3Pool(
            IUniswapV3Factory(clfactory).getPool(
                USDC, WETH, tickSpacing
            )
        ).slot0();

        INonfungiblePositionManager.MintParams[] memory mintParams =
            new INonfungiblePositionManager.MintParams[](1);
        mintParams[0] = INonfungiblePositionManager.MintParams({
            token0: USDC,
            token1: WETH,
            tickSpacing: tickSpacing,
            tickLower: int24(tick - (tick % 100) - 100),
            tickUpper: int24(tick - (tick % 100) + 100),
            amount0Desired: 2614e6,
            amount1Desired: 1 ether,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(module),
            deadline: type(uint256).max,
            sqrtPriceX96: 0
        });

        vm.prank(arrakisStandardManager);
        vm.expectRevert(
            IVelodromeStandardModulePrivate.WrongRouter.selector
        );
        IVelodromeStandardModulePrivate(module).rebalance(
            RebalanceParams({
                decreasePositions: modifyPositions,
                increasePositions: modifyPositions,
                swapPayload: swapPayload,
                mintParams: mintParams,
                minBurn0: 0,
                minBurn1: 0,
                minDeposit0: 0,
                minDeposit1: 0
            })
        );

        // #endregion rebalance.
    }

    function test_rebalance_with_swap_zero_for_one_slippage_too_high()
        public
    {
        // #region deposit.

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));

        uint256 amount0 = 0;
        uint256 amount1 = 2 ether;

        deal(WETH, depositor, amount1);

        // #region approve the module.

        vm.startPrank(depositor);
        IERC20Metadata(WETH).approve(module, amount1);
        vm.stopPrank();

        // #endregion approve the module.

        vm.prank(address(vault));
        IArrakisLPModulePrivate(module).fund(
            depositor, amount0, amount1
        );

        // #endregion deposit.

        // #region rebalance with swap.

        // Zero for one swap.

        ModifyPosition[] memory modifyPositions =
            new ModifyPosition[](0);
        SwapPayload memory swapPayload;

        swapPayload.amountIn = 1 ether;
        swapPayload.expectedMinReturn = 2614e6;
        swapPayload.router = address(this);
        swapPayload.payload = abi.encodeWithSelector(
            this.swapZeroForOneSlippage.selector
        );
        swapPayload.zeroForOne = false;

        int24 tickSpacing = 100;

        (, int24 tick,,,,) = IUniswapV3Pool(
            IUniswapV3Factory(clfactory).getPool(
                USDC, WETH, tickSpacing
            )
        ).slot0();

        INonfungiblePositionManager.MintParams[] memory mintParams =
            new INonfungiblePositionManager.MintParams[](1);
        mintParams[0] = INonfungiblePositionManager.MintParams({
            token0: USDC,
            token1: WETH,
            tickSpacing: tickSpacing,
            tickLower: int24(tick - (tick % 100) - 100),
            tickUpper: int24(tick - (tick % 100) + 100),
            amount0Desired: 2614e6,
            amount1Desired: 1 ether,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(module),
            deadline: type(uint256).max,
            sqrtPriceX96: 0
        });

        vm.prank(arrakisStandardManager);
        vm.expectRevert(
            IVelodromeStandardModulePrivate.SlippageTooHigh.selector
        );
        IVelodromeStandardModulePrivate(module).rebalance(
            RebalanceParams({
                decreasePositions: modifyPositions,
                increasePositions: modifyPositions,
                swapPayload: swapPayload,
                mintParams: mintParams,
                minBurn0: 0,
                minBurn1: 0,
                minDeposit0: 0,
                minDeposit1: 0
            })
        );

        // #endregion rebalance.
    }

    function test_rebalance_with_swap_one_for_zero_slippage_too_high()
        public
    {
        // #region deposit.

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));

        uint256 amount0 = 2614e6 * 2;
        uint256 amount1 = 0;

        deal(USDC, depositor, amount0);

        // #region approve the module.

        vm.startPrank(depositor);
        IERC20Metadata(USDC).approve(module, amount0);
        vm.stopPrank();

        // #endregion approve the module.

        vm.prank(address(vault));
        IArrakisLPModulePrivate(module).fund(
            depositor, amount0, amount1
        );

        // #endregion deposit.

        // #region rebalance with swap.

        // Zero for one swap.

        ModifyPosition[] memory modifyPositions =
            new ModifyPosition[](0);
        SwapPayload memory swapPayload;

        swapPayload.amountIn = 2614e6;
        swapPayload.expectedMinReturn = 1 ether;
        swapPayload.router = address(this);
        swapPayload.payload = abi.encodeWithSelector(
            this.swapOneForZeroSlippage.selector
        );
        swapPayload.zeroForOne = true;

        int24 tickSpacing = 100;

        (, int24 tick,,,,) = IUniswapV3Pool(
            IUniswapV3Factory(clfactory).getPool(
                USDC, WETH, tickSpacing
            )
        ).slot0();

        INonfungiblePositionManager.MintParams[] memory mintParams =
            new INonfungiblePositionManager.MintParams[](1);
        mintParams[0] = INonfungiblePositionManager.MintParams({
            token0: USDC,
            token1: WETH,
            tickSpacing: tickSpacing,
            tickLower: int24(tick - (tick % 100) - 100),
            tickUpper: int24(tick - (tick % 100) + 100),
            amount0Desired: 2614e6,
            amount1Desired: 1 ether,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(module),
            deadline: type(uint256).max,
            sqrtPriceX96: 0
        });

        vm.prank(arrakisStandardManager);
        vm.expectRevert(
            IVelodromeStandardModulePrivate.SlippageTooHigh.selector
        );
        IVelodromeStandardModulePrivate(module).rebalance(
            RebalanceParams({
                decreasePositions: modifyPositions,
                increasePositions: modifyPositions,
                swapPayload: swapPayload,
                mintParams: mintParams,
                minBurn0: 0,
                minBurn1: 0,
                minDeposit0: 0,
                minDeposit1: 0
            })
        );

        // #endregion rebalance.
    }

    function test_rebalance_increase_position() public {
        // #region deposit.

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));

        uint256 amount0 = 0;
        uint256 amount1 = 2 ether;

        deal(WETH, depositor, amount1);

        // #region approve the module.

        vm.startPrank(depositor);
        IERC20Metadata(WETH).approve(module, amount1);
        vm.stopPrank();

        // #endregion approve the module.

        vm.prank(address(vault));
        IArrakisLPModulePrivate(module).fund(
            depositor, amount0, amount1
        );

        // #endregion deposit.

        // #region rebalance with swap.

        // Zero for one swap.

        ModifyPosition[] memory modifyPositions =
            new ModifyPosition[](0);
        SwapPayload memory swapPayload;

        swapPayload.amountIn = 1 ether;
        swapPayload.expectedMinReturn = 2610e6;
        swapPayload.router = address(this);
        swapPayload.payload =
            abi.encodeWithSelector(this.swap.selector);
        swapPayload.zeroForOne = false;

        int24 tickSpacing = 100;

        (, int24 tick,,,,) = IUniswapV3Pool(
            IUniswapV3Factory(clfactory).getPool(
                USDC, WETH, tickSpacing
            )
        ).slot0();

        INonfungiblePositionManager.MintParams[] memory mintParams =
            new INonfungiblePositionManager.MintParams[](1);
        mintParams[0] = INonfungiblePositionManager.MintParams({
            token0: USDC,
            token1: WETH,
            tickSpacing: tickSpacing,
            tickLower: int24(tick - (tick % 100) - 100),
            tickUpper: int24(tick - (tick % 100) + 100),
            amount0Desired: 2614e6,
            amount1Desired: 1 ether,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(module),
            deadline: type(uint256).max,
            sqrtPriceX96: 0
        });

        vm.prank(arrakisStandardManager);
        IVelodromeStandardModulePrivate(module).rebalance(
            RebalanceParams({
                decreasePositions: modifyPositions,
                increasePositions: modifyPositions,
                swapPayload: swapPayload,
                mintParams: mintParams,
                minBurn0: 0,
                minBurn1: 0,
                minDeposit0: 0,
                minDeposit1: 0
            })
        );

        // #endregion rebalance.

        // #region second deposit.

        deal(WETH, depositor, amount1);

        // #region approve the module.

        vm.startPrank(depositor);
        IERC20Metadata(WETH).approve(module, amount1);
        vm.stopPrank();

        // #endregion approve the module.

        vm.prank(address(vault));
        IArrakisLPModulePrivate(module).fund(
            depositor, amount0, amount1
        );

        // #endregion second deposit.

        // #region second rebalance for increasing positions.

        uint256[] memory tokenIds =
            IVelodromeStandardModulePrivate(module).tokenIds();

        mintParams = new INonfungiblePositionManager.MintParams[](0);
        modifyPositions = new ModifyPosition[](1);

        modifyPositions[0].tokenId = tokenIds[0];
        modifyPositions[0].proportion = BASE;

        vm.prank(arrakisStandardManager);
        IVelodromeStandardModulePrivate(module).rebalance(
            RebalanceParams({
                decreasePositions: new ModifyPosition[](0),
                increasePositions: modifyPositions,
                swapPayload: swapPayload,
                mintParams: mintParams,
                minBurn0: 0,
                minBurn1: 0,
                minDeposit0: 0,
                minDeposit1: 0
            })
        );

        // #endregion second rebalance for increasing positions.
    }

    function test_rebalance_increase_position_token_id_not_found()
        public
    {
        // #region deposit.

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));

        uint256 amount0 = 0;
        uint256 amount1 = 2 ether;

        deal(WETH, depositor, amount1);

        // #region approve the module.

        vm.startPrank(depositor);
        IERC20Metadata(WETH).approve(module, amount1);
        vm.stopPrank();

        // #endregion approve the module.

        vm.prank(address(vault));
        IArrakisLPModulePrivate(module).fund(
            depositor, amount0, amount1
        );

        // #endregion deposit.

        // #region rebalance with swap.

        // Zero for one swap.

        ModifyPosition[] memory modifyPositions =
            new ModifyPosition[](0);
        SwapPayload memory swapPayload;

        swapPayload.amountIn = 1 ether;
        swapPayload.expectedMinReturn = 2610e6;
        swapPayload.router = address(this);
        swapPayload.payload =
            abi.encodeWithSelector(this.swap.selector);
        swapPayload.zeroForOne = false;

        int24 tickSpacing = 100;

        (, int24 tick,,,,) = IUniswapV3Pool(
            IUniswapV3Factory(clfactory).getPool(
                USDC, WETH, tickSpacing
            )
        ).slot0();

        INonfungiblePositionManager.MintParams[] memory mintParams =
            new INonfungiblePositionManager.MintParams[](1);
        mintParams[0] = INonfungiblePositionManager.MintParams({
            token0: USDC,
            token1: WETH,
            tickSpacing: tickSpacing,
            tickLower: int24(tick - (tick % 100) - 100),
            tickUpper: int24(tick - (tick % 100) + 100),
            amount0Desired: 2614e6,
            amount1Desired: 1 ether,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(module),
            deadline: type(uint256).max,
            sqrtPriceX96: 0
        });

        vm.prank(arrakisStandardManager);
        IVelodromeStandardModulePrivate(module).rebalance(
            RebalanceParams({
                decreasePositions: modifyPositions,
                increasePositions: modifyPositions,
                swapPayload: swapPayload,
                mintParams: mintParams,
                minBurn0: 0,
                minBurn1: 0,
                minDeposit0: 0,
                minDeposit1: 0
            })
        );

        // #endregion rebalance.

        // #region second deposit.

        deal(WETH, depositor, amount1);

        // #region approve the module.

        vm.startPrank(depositor);
        IERC20Metadata(WETH).approve(module, amount1);
        vm.stopPrank();

        // #endregion approve the module.

        vm.prank(address(vault));
        IArrakisLPModulePrivate(module).fund(
            depositor, amount0, amount1
        );

        // #endregion second deposit.

        // #region second rebalance for increasing positions.

        uint256[] memory tokenIds =
            IVelodromeStandardModulePrivate(module).tokenIds();

        mintParams = new INonfungiblePositionManager.MintParams[](0);
        modifyPositions = new ModifyPosition[](1);

        modifyPositions[0].tokenId = tokenIds[0] + 1;
        modifyPositions[0].proportion = BASE;

        vm.prank(arrakisStandardManager);
        vm.expectRevert(
            IVelodromeStandardModulePrivate.TokenIdNotFound.selector
        );
        IVelodromeStandardModulePrivate(module).rebalance(
            RebalanceParams({
                decreasePositions: new ModifyPosition[](0),
                increasePositions: modifyPositions,
                swapPayload: swapPayload,
                mintParams: mintParams,
                minBurn0: 0,
                minBurn1: 0,
                minDeposit0: 0,
                minDeposit1: 0
            })
        );

        // #endregion second rebalance for increasing positions.
    }

    function test_rebalance_mint_token_1() public {
        // #region deposit.

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));

        uint256 amount0 = 0;
        uint256 amount1 = 2 ether;

        deal(WETH, depositor, amount1);

        // #region approve the module.

        vm.startPrank(depositor);
        IERC20Metadata(WETH).approve(module, amount1);
        vm.stopPrank();

        // #endregion approve the module.

        vm.prank(address(vault));
        IArrakisLPModulePrivate(module).fund(
            depositor, amount0, amount1
        );

        // #endregion deposit.

        // #region rebalance with swap.

        // Zero for one swap.

        ModifyPosition[] memory modifyPositions =
            new ModifyPosition[](0);
        SwapPayload memory swapPayload;

        swapPayload.amountIn = 1 ether;
        swapPayload.expectedMinReturn = 2610e6;
        swapPayload.router = address(this);
        swapPayload.payload =
            abi.encodeWithSelector(this.swap.selector);
        swapPayload.zeroForOne = false;

        int24 tickSpacing = 100;

        (, int24 tick,,,,) = IUniswapV3Pool(
            IUniswapV3Factory(clfactory).getPool(
                USDC, WETH, tickSpacing
            )
        ).slot0();

        INonfungiblePositionManager.MintParams[] memory mintParams =
            new INonfungiblePositionManager.MintParams[](1);
        mintParams[0] = INonfungiblePositionManager.MintParams({
            token0: USDC,
            token1: WETH,
            tickSpacing: tickSpacing,
            tickLower: int24(tick - (tick % 100) - 100),
            tickUpper: int24(tick - (tick % 100) + 100),
            amount0Desired: 2614e6,
            amount1Desired: 1 ether,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(module),
            deadline: type(uint256).max,
            sqrtPriceX96: 0
        });

        vm.prank(arrakisStandardManager);
        vm.expectRevert(
            IVelodromeStandardModulePrivate.MintToken1.selector
        );
        IVelodromeStandardModulePrivate(module).rebalance(
            RebalanceParams({
                decreasePositions: modifyPositions,
                increasePositions: modifyPositions,
                swapPayload: swapPayload,
                mintParams: mintParams,
                minBurn0: 0,
                minBurn1: 0,
                minDeposit0: 0,
                minDeposit1: 2 ether
            })
        );

        // #endregion rebalance.
    }

    function test_rebalance_mint_token_0() public {
        // #region deposit.

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));

        uint256 amount0 = 0;
        uint256 amount1 = 2 ether;

        deal(WETH, depositor, amount1);

        // #region approve the module.

        vm.startPrank(depositor);
        IERC20Metadata(WETH).approve(module, amount1);
        vm.stopPrank();

        // #endregion approve the module.

        vm.prank(address(vault));
        IArrakisLPModulePrivate(module).fund(
            depositor, amount0, amount1
        );

        // #endregion deposit.

        // #region rebalance with swap.

        // Zero for one swap.

        ModifyPosition[] memory modifyPositions =
            new ModifyPosition[](0);
        SwapPayload memory swapPayload;

        swapPayload.amountIn = 1 ether;
        swapPayload.expectedMinReturn = 2610e6;
        swapPayload.router = address(this);
        swapPayload.payload =
            abi.encodeWithSelector(this.swap.selector);
        swapPayload.zeroForOne = false;

        int24 tickSpacing = 100;

        (, int24 tick,,,,) = IUniswapV3Pool(
            IUniswapV3Factory(clfactory).getPool(
                USDC, WETH, tickSpacing
            )
        ).slot0();

        INonfungiblePositionManager.MintParams[] memory mintParams =
            new INonfungiblePositionManager.MintParams[](1);
        mintParams[0] = INonfungiblePositionManager.MintParams({
            token0: USDC,
            token1: WETH,
            tickSpacing: tickSpacing,
            tickLower: int24(tick - (tick % 100) - 100),
            tickUpper: int24(tick - (tick % 100) + 100),
            amount0Desired: 2614e6,
            amount1Desired: 1 ether,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(module),
            deadline: type(uint256).max,
            sqrtPriceX96: 0
        });

        vm.prank(arrakisStandardManager);
        vm.expectRevert(
            IVelodromeStandardModulePrivate.MintToken0.selector
        );
        IVelodromeStandardModulePrivate(module).rebalance(
            RebalanceParams({
                decreasePositions: modifyPositions,
                increasePositions: modifyPositions,
                swapPayload: swapPayload,
                mintParams: mintParams,
                minBurn0: 0,
                minBurn1: 0,
                minDeposit0: 3415e6,
                minDeposit1: 0
            })
        );

        // #endregion rebalance.
    }

    function test_rebalance_token_0_mismatch() public {
        // #region deposit.

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));

        uint256 amount0 = 0;
        uint256 amount1 = 2 ether;

        deal(WETH, depositor, amount1);

        // #region approve the module.

        vm.startPrank(depositor);
        IERC20Metadata(WETH).approve(module, amount1);
        vm.stopPrank();

        // #endregion approve the module.

        vm.prank(address(vault));
        IArrakisLPModulePrivate(module).fund(
            depositor, amount0, amount1
        );

        // #endregion deposit.

        // #region rebalance with swap.

        // Zero for one swap.

        ModifyPosition[] memory modifyPositions =
            new ModifyPosition[](0);
        SwapPayload memory swapPayload;

        swapPayload.amountIn = 1 ether;
        swapPayload.expectedMinReturn = 2610e6;
        swapPayload.router = address(this);
        swapPayload.payload =
            abi.encodeWithSelector(this.swap.selector);
        swapPayload.zeroForOne = false;

        int24 tickSpacing = 100;

        (, int24 tick,,,,) = IUniswapV3Pool(
            IUniswapV3Factory(clfactory).getPool(
                USDC, WETH, tickSpacing
            )
        ).slot0();

        INonfungiblePositionManager.MintParams[] memory mintParams =
            new INonfungiblePositionManager.MintParams[](1);
        mintParams[0] = INonfungiblePositionManager.MintParams({
            token0: WETH,
            token1: WETH,
            tickSpacing: tickSpacing,
            tickLower: int24(tick - (tick % 100) - 100),
            tickUpper: int24(tick - (tick % 100) + 100),
            amount0Desired: 2614e6,
            amount1Desired: 1 ether,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(module),
            deadline: type(uint256).max,
            sqrtPriceX96: 0
        });

        vm.prank(arrakisStandardManager);
        vm.expectRevert(
            IVelodromeStandardModulePrivate.Token0Mismatch.selector
        );
        IVelodromeStandardModulePrivate(module).rebalance(
            RebalanceParams({
                decreasePositions: modifyPositions,
                increasePositions: modifyPositions,
                swapPayload: swapPayload,
                mintParams: mintParams,
                minBurn0: 0,
                minBurn1: 0,
                minDeposit0: 2614e6,
                minDeposit1: 0
            })
        );

        // #endregion rebalance.
    }

    function test_rebalance_token_1_mismatch() public {
        // #region deposit.

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));

        uint256 amount0 = 0;
        uint256 amount1 = 2 ether;

        deal(WETH, depositor, amount1);

        // #region approve the module.

        vm.startPrank(depositor);
        IERC20Metadata(WETH).approve(module, amount1);
        vm.stopPrank();

        // #endregion approve the module.

        vm.prank(address(vault));
        IArrakisLPModulePrivate(module).fund(
            depositor, amount0, amount1
        );

        // #endregion deposit.

        // #region rebalance with swap.

        // Zero for one swap.

        ModifyPosition[] memory modifyPositions =
            new ModifyPosition[](0);
        SwapPayload memory swapPayload;

        swapPayload.amountIn = 1 ether;
        swapPayload.expectedMinReturn = 2610e6;
        swapPayload.router = address(this);
        swapPayload.payload =
            abi.encodeWithSelector(this.swap.selector);
        swapPayload.zeroForOne = false;

        int24 tickSpacing = 100;

        (, int24 tick,,,,) = IUniswapV3Pool(
            IUniswapV3Factory(clfactory).getPool(
                USDC, WETH, tickSpacing
            )
        ).slot0();

        INonfungiblePositionManager.MintParams[] memory mintParams =
            new INonfungiblePositionManager.MintParams[](1);
        mintParams[0] = INonfungiblePositionManager.MintParams({
            token0: USDC,
            token1: USDC,
            tickSpacing: tickSpacing,
            tickLower: int24(tick - (tick % 100) - 100),
            tickUpper: int24(tick - (tick % 100) + 100),
            amount0Desired: 2614e6,
            amount1Desired: 1 ether,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(module),
            deadline: type(uint256).max,
            sqrtPriceX96: 0
        });

        vm.prank(arrakisStandardManager);
        vm.expectRevert(
            IVelodromeStandardModulePrivate.Token1Mismatch.selector
        );
        IVelodromeStandardModulePrivate(module).rebalance(
            RebalanceParams({
                decreasePositions: modifyPositions,
                increasePositions: modifyPositions,
                swapPayload: swapPayload,
                mintParams: mintParams,
                minBurn0: 0,
                minBurn1: 0,
                minDeposit0: 2614e6,
                minDeposit1: 0
            })
        );

        // #endregion rebalance.
    }

    function test_rebalance_tick_spacing_mismatch() public {
        // #region deposit.

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));

        uint256 amount0 = 0;
        uint256 amount1 = 2 ether;

        deal(WETH, depositor, amount1);

        // #region approve the module.

        vm.startPrank(depositor);
        IERC20Metadata(WETH).approve(module, amount1);
        vm.stopPrank();

        // #endregion approve the module.

        vm.prank(address(vault));
        IArrakisLPModulePrivate(module).fund(
            depositor, amount0, amount1
        );

        // #endregion deposit.

        // #region rebalance with swap.

        // Zero for one swap.

        ModifyPosition[] memory modifyPositions =
            new ModifyPosition[](0);
        SwapPayload memory swapPayload;

        swapPayload.amountIn = 1 ether;
        swapPayload.expectedMinReturn = 2610e6;
        swapPayload.router = address(this);
        swapPayload.payload =
            abi.encodeWithSelector(this.swap.selector);
        swapPayload.zeroForOne = false;

        int24 tickSpacing = 100;

        (, int24 tick,,,,) = IUniswapV3Pool(
            IUniswapV3Factory(clfactory).getPool(
                USDC, WETH, tickSpacing
            )
        ).slot0();

        INonfungiblePositionManager.MintParams[] memory mintParams =
            new INonfungiblePositionManager.MintParams[](1);
        mintParams[0] = INonfungiblePositionManager.MintParams({
            token0: USDC,
            token1: WETH,
            tickSpacing: tickSpacing + 1,
            tickLower: int24(tick - (tick % 100) - 100),
            tickUpper: int24(tick - (tick % 100) + 100),
            amount0Desired: 2614e6,
            amount1Desired: 1 ether,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(module),
            deadline: type(uint256).max,
            sqrtPriceX96: 0
        });

        vm.prank(arrakisStandardManager);
        vm.expectRevert(
            IVelodromeStandardModulePrivate
                .TickSpacingMismatch
                .selector
        );
        IVelodromeStandardModulePrivate(module).rebalance(
            RebalanceParams({
                decreasePositions: modifyPositions,
                increasePositions: modifyPositions,
                swapPayload: swapPayload,
                mintParams: mintParams,
                minBurn0: 0,
                minBurn1: 0,
                minDeposit0: 0,
                minDeposit1: 2614e6
            })
        );

        // #endregion rebalance.
    }

    function test_rebalance_token_not_found() public {
        // #region deposit.

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));

        uint256 amount0 = 0;
        uint256 amount1 = 2 ether;

        deal(WETH, depositor, amount1);

        // #region approve the module.

        vm.startPrank(depositor);
        IERC20Metadata(WETH).approve(module, amount1);
        vm.stopPrank();

        // #endregion approve the module.

        vm.prank(address(vault));
        IArrakisLPModulePrivate(module).fund(
            depositor, amount0, amount1
        );

        // #endregion deposit.

        // #region rebalance with swap.

        // Zero for one swap.

        ModifyPosition[] memory modifyPositions =
            new ModifyPosition[](0);
        SwapPayload memory swapPayload;

        swapPayload.amountIn = 1 ether;
        swapPayload.expectedMinReturn = 2610e6;
        swapPayload.router = address(this);
        swapPayload.payload =
            abi.encodeWithSelector(this.swap.selector);
        swapPayload.zeroForOne = false;

        int24 tickSpacing = 100;

        (, int24 tick,,,,) = IUniswapV3Pool(
            IUniswapV3Factory(clfactory).getPool(
                USDC, WETH, tickSpacing
            )
        ).slot0();

        INonfungiblePositionManager.MintParams[] memory mintParams =
            new INonfungiblePositionManager.MintParams[](1);
        mintParams[0] = INonfungiblePositionManager.MintParams({
            token0: USDC,
            token1: WETH,
            tickSpacing: tickSpacing,
            tickLower: int24(tick - (tick % 100) - 100),
            tickUpper: int24(tick - (tick % 100) + 100),
            amount0Desired: 2614e6,
            amount1Desired: 1 ether,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(module),
            deadline: type(uint256).max,
            sqrtPriceX96: 0
        });

        vm.prank(arrakisStandardManager);
        IVelodromeStandardModulePrivate(module).rebalance(
            RebalanceParams({
                decreasePositions: modifyPositions,
                increasePositions: modifyPositions,
                swapPayload: swapPayload,
                mintParams: mintParams,
                minBurn0: 0,
                minBurn1: 0,
                minDeposit0: 0,
                minDeposit1: 0
            })
        );

        // #endregion rebalance.

        // #region second rebalance to burn position.

        uint256[] memory tokenId =
            VelodromeStandardModulePrivate(module).tokenIds();

        modifyPositions = new ModifyPosition[](1);
        SwapPayload memory swapPayload2;
        mintParams = new INonfungiblePositionManager.MintParams[](0);

        modifyPositions[0] =
            ModifyPosition({tokenId: 1, proportion: BASE});

        vm.prank(arrakisStandardManager);
        vm.expectRevert(
            IVelodromeStandardModulePrivate.TokenIdNotFound.selector
        );
        IVelodromeStandardModulePrivate(module).rebalance(
            RebalanceParams({
                decreasePositions: modifyPositions,
                increasePositions: new ModifyPosition[](0),
                swapPayload: swapPayload2,
                mintParams: mintParams,
                minBurn0: 0,
                minBurn1: 0,
                minDeposit0: 0,
                minDeposit1: 0
            })
        );

        // #endregion second rebalance to burn position.
    }

    function test_rebalance_burn_token_1() public {
        // #region deposit.

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));

        uint256 amount0 = 0;
        uint256 amount1 = 2 ether;

        deal(WETH, depositor, amount1);

        // #region approve the module.

        vm.startPrank(depositor);
        IERC20Metadata(WETH).approve(module, amount1);
        vm.stopPrank();

        // #endregion approve the module.

        vm.prank(address(vault));
        IArrakisLPModulePrivate(module).fund(
            depositor, amount0, amount1
        );

        // #endregion deposit.

        // #region rebalance with swap.

        // Zero for one swap.

        ModifyPosition[] memory modifyPositions =
            new ModifyPosition[](0);
        SwapPayload memory swapPayload;

        swapPayload.amountIn = 1 ether;
        swapPayload.expectedMinReturn = 2610e6;
        swapPayload.router = address(this);
        swapPayload.payload =
            abi.encodeWithSelector(this.swap.selector);
        swapPayload.zeroForOne = false;

        int24 tickSpacing = 100;

        (, int24 tick,,,,) = IUniswapV3Pool(
            IUniswapV3Factory(clfactory).getPool(
                USDC, WETH, tickSpacing
            )
        ).slot0();

        INonfungiblePositionManager.MintParams[] memory mintParams =
            new INonfungiblePositionManager.MintParams[](1);
        mintParams[0] = INonfungiblePositionManager.MintParams({
            token0: USDC,
            token1: WETH,
            tickSpacing: tickSpacing,
            tickLower: int24(tick - (tick % 100) - 100),
            tickUpper: int24(tick - (tick % 100) + 100),
            amount0Desired: 2614e6,
            amount1Desired: 1 ether,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(module),
            deadline: type(uint256).max,
            sqrtPriceX96: 0
        });

        vm.prank(arrakisStandardManager);
        IVelodromeStandardModulePrivate(module).rebalance(
            RebalanceParams({
                decreasePositions: modifyPositions,
                increasePositions: modifyPositions,
                swapPayload: swapPayload,
                mintParams: mintParams,
                minBurn0: 0,
                minBurn1: 0,
                minDeposit0: 0,
                minDeposit1: 0
            })
        );

        // #endregion rebalance.

        // #region second rebalance to burn position.

        uint256[] memory tokenId =
            VelodromeStandardModulePrivate(module).tokenIds();

        modifyPositions = new ModifyPosition[](1);
        SwapPayload memory swapPayload2;
        mintParams = new INonfungiblePositionManager.MintParams[](0);

        modifyPositions[0] =
            ModifyPosition({tokenId: tokenId[0], proportion: BASE});

        vm.prank(arrakisStandardManager);
        vm.expectRevert(
            IVelodromeStandardModulePrivate.BurnToken1.selector
        );
        IVelodromeStandardModulePrivate(module).rebalance(
            RebalanceParams({
                decreasePositions: modifyPositions,
                increasePositions: new ModifyPosition[](0),
                swapPayload: swapPayload2,
                mintParams: mintParams,
                minBurn0: 0,
                minBurn1: 2 ether,
                minDeposit0: 0,
                minDeposit1: 0
            })
        );

        // #endregion second rebalance to burn position.
    }

    function test_rebalance_burn_token_0() public {
        // #region deposit.

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));

        uint256 amount0 = 0;
        uint256 amount1 = 2 ether;

        deal(WETH, depositor, amount1);

        // #region approve the module.

        vm.startPrank(depositor);
        IERC20Metadata(WETH).approve(module, amount1);
        vm.stopPrank();

        // #endregion approve the module.

        vm.prank(address(vault));
        IArrakisLPModulePrivate(module).fund(
            depositor, amount0, amount1
        );

        // #endregion deposit.

        // #region rebalance with swap.

        // Zero for one swap.

        ModifyPosition[] memory modifyPositions =
            new ModifyPosition[](0);
        SwapPayload memory swapPayload;

        swapPayload.amountIn = 1 ether;
        swapPayload.expectedMinReturn = 2610e6;
        swapPayload.router = address(this);
        swapPayload.payload =
            abi.encodeWithSelector(this.swap.selector);
        swapPayload.zeroForOne = false;

        int24 tickSpacing = 100;

        (, int24 tick,,,,) = IUniswapV3Pool(
            IUniswapV3Factory(clfactory).getPool(
                USDC, WETH, tickSpacing
            )
        ).slot0();

        INonfungiblePositionManager.MintParams[] memory mintParams =
            new INonfungiblePositionManager.MintParams[](1);
        mintParams[0] = INonfungiblePositionManager.MintParams({
            token0: USDC,
            token1: WETH,
            tickSpacing: tickSpacing,
            tickLower: int24(tick - (tick % 100) - 100),
            tickUpper: int24(tick - (tick % 100) + 100),
            amount0Desired: 2614e6,
            amount1Desired: 1 ether,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(module),
            deadline: type(uint256).max,
            sqrtPriceX96: 0
        });

        vm.prank(arrakisStandardManager);
        IVelodromeStandardModulePrivate(module).rebalance(
            RebalanceParams({
                decreasePositions: modifyPositions,
                increasePositions: modifyPositions,
                swapPayload: swapPayload,
                mintParams: mintParams,
                minBurn0: 0,
                minBurn1: 0,
                minDeposit0: 0,
                minDeposit1: 0
            })
        );

        // #endregion rebalance.

        // #region second rebalance to burn position.

        uint256[] memory tokenId =
            VelodromeStandardModulePrivate(module).tokenIds();

        modifyPositions = new ModifyPosition[](1);
        SwapPayload memory swapPayload2;
        mintParams = new INonfungiblePositionManager.MintParams[](0);

        modifyPositions[0] =
            ModifyPosition({tokenId: tokenId[0], proportion: BASE});

        vm.prank(arrakisStandardManager);
        vm.expectRevert(
            IVelodromeStandardModulePrivate.BurnToken0.selector
        );
        IVelodromeStandardModulePrivate(module).rebalance(
            RebalanceParams({
                decreasePositions: modifyPositions,
                increasePositions: new ModifyPosition[](0),
                swapPayload: swapPayload2,
                mintParams: mintParams,
                minBurn0: 10_000_000_000,
                minBurn1: 0,
                minDeposit0: 0,
                minDeposit1: 0
            })
        );

        // #endregion second rebalance to burn position.
    }

    function test_rebalance_full_burn() public {
        // #region deposit.

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));

        uint256 amount0 = 0;
        uint256 amount1 = 2 ether;

        deal(WETH, depositor, amount1);

        // #region approve the module.

        vm.startPrank(depositor);
        IERC20Metadata(WETH).approve(module, amount1);
        vm.stopPrank();

        // #endregion approve the module.

        vm.prank(address(vault));
        IArrakisLPModulePrivate(module).fund(
            depositor, amount0, amount1
        );

        // #endregion deposit.

        // #region rebalance with swap.

        // Zero for one swap.

        ModifyPosition[] memory modifyPositions =
            new ModifyPosition[](0);
        SwapPayload memory swapPayload;

        swapPayload.amountIn = 1 ether;
        swapPayload.expectedMinReturn = 2610e6;
        swapPayload.router = address(this);
        swapPayload.payload =
            abi.encodeWithSelector(this.swap.selector);
        swapPayload.zeroForOne = false;

        int24 tickSpacing = 100;

        (, int24 tick,,,,) = IUniswapV3Pool(
            IUniswapV3Factory(clfactory).getPool(
                USDC, WETH, tickSpacing
            )
        ).slot0();

        INonfungiblePositionManager.MintParams[] memory mintParams =
            new INonfungiblePositionManager.MintParams[](1);
        mintParams[0] = INonfungiblePositionManager.MintParams({
            token0: USDC,
            token1: WETH,
            tickSpacing: tickSpacing,
            tickLower: int24(tick - (tick % 100) - 100),
            tickUpper: int24(tick - (tick % 100) + 100),
            amount0Desired: 2614e6,
            amount1Desired: 1 ether,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(module),
            deadline: type(uint256).max,
            sqrtPriceX96: 0
        });

        vm.prank(arrakisStandardManager);
        IVelodromeStandardModulePrivate(module).rebalance(
            RebalanceParams({
                decreasePositions: modifyPositions,
                increasePositions: modifyPositions,
                swapPayload: swapPayload,
                mintParams: mintParams,
                minBurn0: 0,
                minBurn1: 0,
                minDeposit0: 0,
                minDeposit1: 0
            })
        );

        // #endregion rebalance.

        // #region second rebalance to burn position.

        uint256[] memory tokenId =
            VelodromeStandardModulePrivate(module).tokenIds();

        modifyPositions = new ModifyPosition[](1);
        SwapPayload memory swapPayload2;
        mintParams = new INonfungiblePositionManager.MintParams[](0);

        modifyPositions[0] =
            ModifyPosition({tokenId: tokenId[0], proportion: BASE});

        vm.prank(arrakisStandardManager);
        IVelodromeStandardModulePrivate(module).rebalance(
            RebalanceParams({
                decreasePositions: modifyPositions,
                increasePositions: new ModifyPosition[](0),
                swapPayload: swapPayload2,
                mintParams: mintParams,
                minBurn0: 0,
                minBurn1: 0,
                minDeposit0: 0,
                minDeposit1: 0
            })
        );

        // #endregion second rebalance to burn position.
    }

    function test_rebalance_partial_burn() public {
        // #region deposit.

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));

        uint256 amount0 = 0;
        uint256 amount1 = 2 ether;

        deal(WETH, depositor, amount1);

        // #region approve the module.

        vm.startPrank(depositor);
        IERC20Metadata(WETH).approve(module, amount1);
        vm.stopPrank();

        // #endregion approve the module.

        vm.prank(address(vault));
        IArrakisLPModulePrivate(module).fund(
            depositor, amount0, amount1
        );

        // #endregion deposit.

        // #region rebalance with swap.

        // Zero for one swap.

        ModifyPosition[] memory modifyPositions =
            new ModifyPosition[](0);
        SwapPayload memory swapPayload;

        swapPayload.amountIn = 1 ether;
        swapPayload.expectedMinReturn = 2610e6;
        swapPayload.router = address(this);
        swapPayload.payload =
            abi.encodeWithSelector(this.swap.selector);
        swapPayload.zeroForOne = false;

        int24 tickSpacing = 100;

        (, int24 tick,,,,) = IUniswapV3Pool(
            IUniswapV3Factory(clfactory).getPool(
                USDC, WETH, tickSpacing
            )
        ).slot0();

        INonfungiblePositionManager.MintParams[] memory mintParams =
            new INonfungiblePositionManager.MintParams[](1);
        mintParams[0] = INonfungiblePositionManager.MintParams({
            token0: USDC,
            token1: WETH,
            tickSpacing: tickSpacing,
            tickLower: int24(tick - (tick % 100) - 100),
            tickUpper: int24(tick - (tick % 100) + 100),
            amount0Desired: 2614e6,
            amount1Desired: 1 ether,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(module),
            deadline: type(uint256).max,
            sqrtPriceX96: 0
        });

        vm.prank(arrakisStandardManager);
        IVelodromeStandardModulePrivate(module).rebalance(
            RebalanceParams({
                decreasePositions: modifyPositions,
                increasePositions: modifyPositions,
                swapPayload: swapPayload,
                mintParams: mintParams,
                minBurn0: 0,
                minBurn1: 0,
                minDeposit0: 0,
                minDeposit1: 0
            })
        );

        // #endregion rebalance.

        // #region second rebalance to burn position.

        uint256[] memory tokenId =
            VelodromeStandardModulePrivate(module).tokenIds();

        modifyPositions = new ModifyPosition[](1);
        SwapPayload memory swapPayload2;
        mintParams = new INonfungiblePositionManager.MintParams[](0);

        modifyPositions[0] = ModifyPosition({
            tokenId: tokenId[0],
            proportion: BASE / 2
        });

        vm.prank(arrakisStandardManager);
        IVelodromeStandardModulePrivate(module).rebalance(
            RebalanceParams({
                decreasePositions: modifyPositions,
                increasePositions: new ModifyPosition[](0),
                swapPayload: swapPayload2,
                mintParams: mintParams,
                minBurn0: 0,
                minBurn1: 0,
                minDeposit0: 0,
                minDeposit1: 0
            })
        );

        // #endregion second rebalance to burn position.
    }

    // function test_rebalance_

    // #endregion test rebalance.

    // #region test get guardian.

    function test_get_guardian() public {
        address p = IArrakisLPModule(module).guardian();

        assertEq(p, pauser);
    }

    // #endregion test get guardian.

    // #region test tokenIds.

    function test_tokenIds() public {
        // #region setup.

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));

        uint256 amount0 = 2614e6;
        uint256 amount1 = 1 ether;

        deal(USDC, depositor, amount0);
        deal(WETH, depositor, amount1);

        // #region approve the module.

        vm.startPrank(depositor);
        IERC20Metadata(USDC).approve(module, amount0);
        IERC20Metadata(WETH).approve(module, amount1);
        vm.stopPrank();

        // #endregion approve the module.

        // #region deposit.

        vm.prank(address(vault));
        IArrakisLPModulePrivate(module).fund(
            depositor, amount0, amount1
        );

        // #endregion deposit.

        // #region rebalance.

        ModifyPosition[] memory modifyPositions =
            new ModifyPosition[](0);
        SwapPayload memory swapPayload;

        int24 tickSpacing = 100;

        (, int24 tick,,,,) = IUniswapV3Pool(
            IUniswapV3Factory(clfactory).getPool(
                USDC, WETH, tickSpacing
            )
        ).slot0();

        INonfungiblePositionManager.MintParams[] memory mintParams =
            new INonfungiblePositionManager.MintParams[](2);
        mintParams[0] = INonfungiblePositionManager.MintParams({
            token0: USDC,
            token1: WETH,
            tickSpacing: tickSpacing,
            tickLower: int24(tick - (tick % 100) - 100),
            tickUpper: int24(tick - (tick % 100) + 100),
            amount0Desired: 2614e6 / 2,
            amount1Desired: 0.5 ether,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(module),
            deadline: type(uint256).max,
            sqrtPriceX96: 0
        });
        mintParams[1] = INonfungiblePositionManager.MintParams({
            token0: USDC,
            token1: WETH,
            tickSpacing: tickSpacing,
            tickLower: int24(tick - (tick % 100) - 200),
            tickUpper: int24(tick - (tick % 100) + 200),
            amount0Desired: 2614e6 / 2,
            amount1Desired: 0.5 ether,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(module),
            deadline: type(uint256).max,
            sqrtPriceX96: 0
        });

        vm.prank(arrakisStandardManager);
        IVelodromeStandardModulePrivate(module).rebalance(
            RebalanceParams({
                decreasePositions: modifyPositions,
                increasePositions: modifyPositions,
                swapPayload: swapPayload,
                mintParams: mintParams,
                minBurn0: 0,
                minBurn1: 0,
                minDeposit0: 0,
                minDeposit1: 0
            })
        );

        // #endregion rebalance.

        // #endregion setup.

        uint256[] memory tokenIds =
            IVelodromeStandardModulePrivate(module).tokenIds();

        assertEq(tokenIds.length, 2);
    }

    // #endregion test tokenIds.

    // #region test total underlying.

    function test_total_underlying() public {
        // #region setup.

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));

        uint256 amount0 = 2614e6;
        uint256 amount1 = 1 ether;

        deal(USDC, depositor, amount0);
        deal(WETH, depositor, amount1);

        // #region approve the module.

        vm.startPrank(depositor);
        IERC20Metadata(USDC).approve(module, amount0);
        IERC20Metadata(WETH).approve(module, amount1);
        vm.stopPrank();

        // #endregion approve the module.

        // #region deposit.

        vm.prank(address(vault));
        IArrakisLPModulePrivate(module).fund(
            depositor, amount0, amount1
        );

        // #endregion deposit.

        // #region rebalance.

        ModifyPosition[] memory modifyPositions =
            new ModifyPosition[](0);
        SwapPayload memory swapPayload;

        int24 tickSpacing = 100;

        (, int24 tick,,,,) = IUniswapV3Pool(
            IUniswapV3Factory(clfactory).getPool(
                USDC, WETH, tickSpacing
            )
        ).slot0();

        INonfungiblePositionManager.MintParams[] memory mintParams =
            new INonfungiblePositionManager.MintParams[](2);
        mintParams[0] = INonfungiblePositionManager.MintParams({
            token0: USDC,
            token1: WETH,
            tickSpacing: tickSpacing,
            tickLower: int24(tick - (tick % 100) - 100),
            tickUpper: int24(tick - (tick % 100) + 100),
            amount0Desired: 2614e6 / 2,
            amount1Desired: 0.5 ether,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(module),
            deadline: type(uint256).max,
            sqrtPriceX96: 0
        });
        mintParams[1] = INonfungiblePositionManager.MintParams({
            token0: USDC,
            token1: WETH,
            tickSpacing: tickSpacing,
            tickLower: int24(tick - (tick % 100) - 200),
            tickUpper: int24(tick - (tick % 100) + 200),
            amount0Desired: 2614e6 / 2,
            amount1Desired: 0.5 ether,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(module),
            deadline: type(uint256).max,
            sqrtPriceX96: 0
        });

        vm.prank(arrakisStandardManager);
        IVelodromeStandardModulePrivate(module).rebalance(
            RebalanceParams({
                decreasePositions: modifyPositions,
                increasePositions: modifyPositions,
                swapPayload: swapPayload,
                mintParams: mintParams,
                minBurn0: 0,
                minBurn1: 0,
                minDeposit0: 0,
                minDeposit1: 0
            })
        );

        // #endregion rebalance.

        // #endregion setup.

        (amount0, amount1) =
            IArrakisLPModule(module).totalUnderlying();

        /// @dev minus 2 wei because, we are minting two positions.
        assertEq(amount0, 2614e6 - 2);
        assertEq(amount1, 1 ether - 2);
    }

    // #endregion test total underlying.

    // #region test total underlying at price.

    function test_total_underlying_at_price() public {
        // #region setup.

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));

        uint256 amount0 = 3850e6;
        uint256 amount1 = 1 ether;

        deal(USDC, depositor, amount0);
        deal(WETH, depositor, amount1);

        // #region approve the module.

        vm.startPrank(depositor);
        IERC20Metadata(USDC).approve(module, amount0);
        IERC20Metadata(WETH).approve(module, amount1);
        vm.stopPrank();

        // #endregion approve the module.

        // #region deposit.

        vm.prank(address(vault));
        IArrakisLPModulePrivate(module).fund(
            depositor, amount0, amount1
        );

        // #endregion deposit.

        // #region rebalance.

        ModifyPosition[] memory modifyPositions =
            new ModifyPosition[](0);
        SwapPayload memory swapPayload;

        int24 tickSpacing = 100;

        (uint160 sqrtPriceX96, int24 tick,,,,) = IUniswapV3Pool(
            IUniswapV3Factory(clfactory).getPool(
                USDC, WETH, tickSpacing
            )
        ).slot0();

        INonfungiblePositionManager.MintParams[] memory mintParams =
            new INonfungiblePositionManager.MintParams[](2);
        mintParams[0] = INonfungiblePositionManager.MintParams({
            token0: USDC,
            token1: WETH,
            tickSpacing: tickSpacing,
            tickLower: int24(tick - (tick % 100) - 100),
            tickUpper: int24(tick - (tick % 100) + 100),
            amount0Desired: 2614e6 / 2,
            amount1Desired: 0.5 ether,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(module),
            deadline: type(uint256).max,
            sqrtPriceX96: 0
        });
        mintParams[1] = INonfungiblePositionManager.MintParams({
            token0: USDC,
            token1: WETH,
            tickSpacing: tickSpacing,
            tickLower: int24(tick - (tick % 100) - 200),
            tickUpper: int24(tick - (tick % 100) + 200),
            amount0Desired: 2614e6 / 2,
            amount1Desired: 0.5 ether,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(module),
            deadline: type(uint256).max,
            sqrtPriceX96: 0
        });

        vm.prank(arrakisStandardManager);
        IVelodromeStandardModulePrivate(module).rebalance(
            RebalanceParams({
                decreasePositions: modifyPositions,
                increasePositions: modifyPositions,
                swapPayload: swapPayload,
                mintParams: mintParams,
                minBurn0: 0,
                minBurn1: 0,
                minDeposit0: 0,
                minDeposit1: 0
            })
        );

        // #endregion rebalance.

        // #endregion setup.

        uint160 priceX96 = (sqrtPriceX96 * 110 / 100);

        (amount0, amount1) =
            IArrakisLPModule(module).totalUnderlyingAtPrice(priceX96);

        assertEq(amount0, 2196755615);
        assertEq(amount1, 1636310339193540072);
    }

    // #endregion test total underlying at price.

    // #region test validate rebalance.

    function test_validate_rebalance_over_max_deviation() public {
        OracleWrapper(oracle).setPrice0(
            382_450_128_503_243 + (382_450_128_503_243 * 2000) / PIPS
        );

        vm.expectRevert(
            IVelodromeStandardModulePrivate.OverMaxDeviation.selector
        );
        IArrakisLPModule(module).validateRebalance(
            IOracleWrapper(oracle), 1000
        );
    }

    function test_validate_rebalance() public {
        OracleWrapper(oracle).setPrice0(
            382_450_128_503_243 + (382_450_128_503_243 * 1000) / PIPS
        );

        IArrakisLPModule(module).validateRebalance(
            IOracleWrapper(oracle), 3000
        );
    }

    // #endregion test validate rebalance.

    // #region test velo manager balance.

    function test_velo_manager_balance() public {
        uint256 veloManagerBalance = IVelodromeStandardModulePrivate(
            module
        ).veloManagerBalance();

        assertEq(veloManagerBalance, 0);

        // #region setup.

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));

        uint256 amount0 = 2614e6;
        uint256 amount1 = 1 ether;

        deal(USDC, depositor, amount0);
        deal(WETH, depositor, amount1);

        // #region approve the module.

        vm.startPrank(depositor);
        IERC20Metadata(USDC).approve(module, amount0);
        IERC20Metadata(WETH).approve(module, amount1);
        vm.stopPrank();

        // #endregion approve the module.

        // #region deposit.

        vm.prank(address(vault));
        IArrakisLPModulePrivate(module).fund(
            depositor, amount0, amount1
        );

        // #endregion deposit.

        // #region rebalance.

        ModifyPosition[] memory modifyPositions =
            new ModifyPosition[](0);
        SwapPayload memory swapPayload;

        int24 tickSpacing = 100;

        (, int24 tick,,,,) = IUniswapV3Pool(
            IUniswapV3Factory(clfactory).getPool(
                USDC, WETH, tickSpacing
            )
        ).slot0();

        INonfungiblePositionManager.MintParams[] memory mintParams =
            new INonfungiblePositionManager.MintParams[](1);
        mintParams[0] = INonfungiblePositionManager.MintParams({
            token0: USDC,
            token1: WETH,
            tickSpacing: tickSpacing,
            tickLower: int24(tick - (tick % 100) - 100),
            tickUpper: int24(tick - (tick % 100) + 100),
            amount0Desired: 2614e6,
            amount1Desired: 1 ether,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(module),
            deadline: type(uint256).max,
            sqrtPriceX96: 0
        });

        vm.prank(arrakisStandardManager);
        IVelodromeStandardModulePrivate(module).rebalance(
            RebalanceParams({
                decreasePositions: modifyPositions,
                increasePositions: modifyPositions,
                swapPayload: swapPayload,
                mintParams: mintParams,
                minBurn0: 0,
                minBurn1: 0,
                minDeposit0: 0,
                minDeposit1: 0
            })
        );

        // #endregion rebalance.

        uint256 blockNumber = block.number;
        uint256 timestamp = block.timestamp;

        vm.warp(timestamp + 100);
        vm.roll(blockNumber + 100);

        // #region do swap.

        address recipient =
            vm.addr(uint256(keccak256(abi.encode("Recipient"))));
        bool zeroForOne = false;
        int256 amountSpecified = 0.5 ether;

        IUniswapV3Pool pool = IUniswapV3Pool(
            IUniswapV3Factory(clfactory).getPool(
                USDC, WETH, tickSpacing
            )
        );

        assertEq(IERC20Metadata(USDC).balanceOf(recipient), 0);

        pool.swap(
            recipient,
            zeroForOne,
            amountSpecified,
            TickMath.MAX_SQRT_RATIO - 1,
            ""
        );

        assertGt(IERC20Metadata(USDC).balanceOf(recipient), 0);

        // #endregion do swap.

        blockNumber = block.number;
        timestamp = block.timestamp;

        vm.warp(timestamp + 100);
        vm.roll(blockNumber + 100);

        // #endregion setup.

        veloManagerBalance = IVelodromeStandardModulePrivate(module)
            .veloManagerBalance();

        assertGt(veloManagerBalance, 0);
    }

    // #endregion test velo manager balance.

    // #region test withdraw manager balance.

    function test_withdraw_manager_balance() public {
        (uint256 amount0, uint256 amount1) =
            IArrakisLPModule(module).withdrawManagerBalance();

        assertEq(amount0, 0);
        assertEq(amount1, 0);
    }

    // #endregion test withdraw manager balance.

    // #region test get inits.

    function test_get_inits() public {
        (uint256 init0, uint256 init1) =
            IArrakisLPModule(module).getInits();

        assertEq(init0, 0);
        assertEq(init1, 0);
    }

    // #endregion test get inits.

    // #region test manager balance 0.

    function test_manager_balance_0() public {
        (uint256 managerFee0) =
            IArrakisLPModule(module).managerBalance0();

        assertEq(managerFee0, 0);
    }

    // #endregion test manager balance 0.

    // #region test manager balance 1.

    function test_manager_balance_1() public {
        (uint256 managerFee1) =
            IArrakisLPModule(module).managerBalance1();

        assertEq(managerFee1, 0);
    }

    // #endregion test manager balance 1.

    // #region tests functions.

    function test_First_Round() public {
        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));

        uint256 amount0 = 3850e6;
        uint256 amount1 = 1 ether;

        deal(USDC, depositor, amount0);
        deal(WETH, depositor, amount1);

        // #region approve the module.

        vm.startPrank(depositor);
        IERC20Metadata(USDC).approve(module, amount0);
        IERC20Metadata(WETH).approve(module, amount1);
        vm.stopPrank();

        // #endregion approve the module.

        // #region deposit.

        vm.prank(address(vault));
        IArrakisLPModulePrivate(module).fund(
            depositor, amount0, amount1
        );

        // #endregion deposit.

        // #region rebalance.

        ModifyPosition[] memory modifyPositions =
            new ModifyPosition[](0);
        SwapPayload memory swapPayload;

        int24 tickSpacing = 100;

        (, int24 tick,,,,) = IUniswapV3Pool(
            IUniswapV3Factory(clfactory).getPool(
                USDC, WETH, tickSpacing
            )
        ).slot0();

        INonfungiblePositionManager.MintParams[] memory mintParams =
            new INonfungiblePositionManager.MintParams[](1);
        mintParams[0] = INonfungiblePositionManager.MintParams({
            token0: USDC,
            token1: WETH,
            tickSpacing: tickSpacing,
            tickLower: int24(tick - (tick % 100) - 100),
            tickUpper: int24(tick - (tick % 100) + 100),
            amount0Desired: 3850e6,
            amount1Desired: 1 ether,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(module),
            deadline: type(uint256).max,
            sqrtPriceX96: 0
        });

        vm.prank(arrakisStandardManager);
        IVelodromeStandardModulePrivate(module).rebalance(
            RebalanceParams({
                decreasePositions: modifyPositions,
                increasePositions: modifyPositions,
                swapPayload: swapPayload,
                mintParams: mintParams,
                minBurn0: 0,
                minBurn1: 0,
                minDeposit0: 0,
                minDeposit1: 0
            })
        );

        // #endregion rebalance.

        uint256 blockNumber = block.number;
        uint256 timestamp = block.timestamp;

        vm.warp(timestamp + 100);
        vm.roll(blockNumber + 100);

        // #region do swap.

        address recipient =
            vm.addr(uint256(keccak256(abi.encode("Recipient"))));
        bool zeroForOne = false;
        int256 amountSpecified = 0.5 ether;

        IUniswapV3Pool pool = IUniswapV3Pool(
            IUniswapV3Factory(clfactory).getPool(
                USDC, WETH, tickSpacing
            )
        );

        assertEq(IERC20Metadata(USDC).balanceOf(recipient), 0);

        pool.swap(
            recipient,
            zeroForOne,
            amountSpecified,
            TickMath.MAX_SQRT_RATIO - 1,
            ""
        );

        assertGt(IERC20Metadata(USDC).balanceOf(recipient), 0);

        // #endregion do swap.

        blockNumber = block.number;
        timestamp = block.timestamp;

        vm.warp(timestamp + 100);
        vm.roll(blockNumber + 100);

        // #region claim rewards.

        assertEq(IERC20Metadata(VELO).balanceOf(owner), 0);

        vm.prank(owner);
        IVelodromeStandardModulePrivate(module).claimRewards(owner);

        // console.log(
        //     "VELO Balance : ", IERC20Metadata(VELO).balanceOf(owner)
        // );

        assertGt(IERC20Metadata(VELO).balanceOf(owner), 0);

        // #endregion claim rewards.

        // #region claim manager rewards.

        assertEq(IERC20Metadata(VELO).balanceOf(veloReceiver), 0);

        IVelodromeStandardModulePrivate(module).claimManager();

        // console.log(
        //     "VELO Balance : ",
        //     IERC20Metadata(VELO).balanceOf(veloReceiver)
        // );

        assertGt(IERC20Metadata(VELO).balanceOf(veloReceiver), 0);

        // console.log(
        //     "Manager Fee PIPS : %d ",
        //     FullMath.mulDiv(
        //         IERC20Metadata(VELO).balanceOf(veloReceiver),
        //         PIPS,
        //         IERC20Metadata(VELO).balanceOf(owner)
        //     )
        // );

        // console.log("Module balance : %d ", IERC20Metadata(VELO).balanceOf(address(module)));

        // #endregion claim manager rewards.

        // #region withdraw partial.

        address withdrawer =
            vm.addr(uint256(keccak256(abi.encode("Withdrawer"))));

        assertEq(IERC20Metadata(WETH).balanceOf(withdrawer), 0);
        assertEq(IERC20Metadata(USDC).balanceOf(withdrawer), 0);

        vm.prank(address(vault));
        IArrakisLPModule(module).withdraw(withdrawer, BASE / 2);

        assertGt(IERC20Metadata(WETH).balanceOf(withdrawer), 0);
        assertGt(IERC20Metadata(USDC).balanceOf(withdrawer), 0);

        // #endregion withdraw partial.

        // #region do another swap.

        pool.swap(
            recipient,
            zeroForOne,
            amountSpecified,
            TickMath.MAX_SQRT_RATIO - 1,
            ""
        );

        // #endregion do another swap.

        blockNumber = block.number;
        timestamp = block.timestamp;

        vm.warp(timestamp + 100);
        vm.roll(blockNumber + 100);

        // #region full withdraw.

        address withdrawer2 =
            vm.addr(uint256(keccak256(abi.encode("Withdrawer2"))));

        assertEq(IERC20Metadata(WETH).balanceOf(withdrawer2), 0);
        assertEq(IERC20Metadata(USDC).balanceOf(withdrawer2), 0);

        vm.prank(address(vault));
        IArrakisLPModule(module).withdraw(withdrawer2, BASE);

        assertGt(IERC20Metadata(WETH).balanceOf(withdrawer2), 0);
        assertGt(IERC20Metadata(USDC).balanceOf(withdrawer2), 0);

        // #endregion full withdraw.

        // #region final claims.

        vm.startPrank(owner);
        IERC20Metadata(VELO).transfer(
            address(1), IERC20Metadata(VELO).balanceOf(owner)
        );
        vm.stopPrank();
        vm.startPrank(veloReceiver);
        IERC20Metadata(VELO).transfer(
            address(1), IERC20Metadata(VELO).balanceOf(veloReceiver)
        );
        vm.stopPrank();

        assertEq(IERC20Metadata(VELO).balanceOf(owner), 0);
        assertEq(IERC20Metadata(VELO).balanceOf(veloReceiver), 0);

        vm.prank(owner);
        IVelodromeStandardModulePrivate(module).claimRewards(owner);

        IVelodromeStandardModulePrivate(module).claimManager();

        assertGt(IERC20Metadata(VELO).balanceOf(owner), 0);
        assertGt(IERC20Metadata(VELO).balanceOf(veloReceiver), 0);

        // #endregion final claims.
    }

    // #endregion tests functions.

    // #region internal functions.

    function _setup() internal {
        // #region create an uniswap standard module.
        _deployAerodromeStandardModule();
        // #endregion create an uniswap standard module.

        address[] memory beacons = new address[](1);
        beacons[0] = beacon;

        vm.startPrank(IOwnable(privateRegistry).owner());

        IModuleRegistry(privateRegistry).whitelistBeacons(beacons);

        vm.stopPrank();
    }

    function _deployAerodromeStandardModule() internal {
        // #region deploy implementation.

        address implementation = address(
            new VelodromeStandardModulePrivate(
                nonfungiblePositionManager, clfactory, voter, guardian
            )
        );

        // #endregion deploy implementation.

        // #region deploy ugradeable beacon.

        beacon = address(new UpgradeableBeacon(implementation));

        UpgradeableBeacon(beacon).transferOwnership(arrakisTimeLock);

        // #endregion deploy upgradeable beacon.
    }

    // #endregion internal functions.

    // #region swap mock functions.

    function swap() public {
        IERC20Metadata(WETH).transferFrom(
            msg.sender, address(this), 1 ether
        );

        uint256 balance = IERC20Metadata(USDC).balanceOf(msg.sender);

        deal(USDC, msg.sender, balance + 2610e6);
    }

    function swapZeroForOneSlippage() public {
        IERC20Metadata(WETH).transferFrom(
            msg.sender, address(this), 1 ether
        );

        uint256 balance = IERC20Metadata(USDC).balanceOf(msg.sender);

        deal(USDC, msg.sender, balance + 2000e6);
    }

    function swapOneForZeroSlippage() public {
        IERC20Metadata(USDC).transferFrom(
            msg.sender, address(this), 2614e6
        );
        uint256 balance = IERC20Metadata(WETH).balanceOf(msg.sender);

        deal(WETH, msg.sender, balance + 0.5 ether);
    }

    function swapOneForZero() public {
        IERC20Metadata(USDC).transferFrom(
            msg.sender, address(this), 2614e6
        );

        uint256 balance = IERC20Metadata(WETH).balanceOf(msg.sender);
        deal(WETH, msg.sender, balance + 1 ether);
    }

    // #endregion swap mock functions.
}
