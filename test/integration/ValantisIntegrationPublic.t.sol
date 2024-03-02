// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// #region foundry.

import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";

// #endregion foundry.

import {TestWrapper} from "../utils/TestWrapper.sol";

import {ModulePublicRegistry} from
    "../../src/ModulePublicRegistry.sol";
import {ArrakisMetaVaultPublic} from
    "../../src/ArrakisMetaVaultPublic.sol";
import {ArrakisMetaVaultFactory} from
    "../../src/ArrakisMetaVaultFactory.sol";
import {ArrakisPublicVaultRouter} from
    "../../src/ArrakisPublicVaultRouter.sol";
import {RouterSwapExecutor} from "../../src/RouterSwapExecutor.sol";
import {ArrakisStandardManager} from
    "../../src/ArrakisStandardManager.sol";
import {Guardian} from "../../src/Guardian.sol";
import {ValantisModulePublic} from
    "../../src/modules/ValantisSOTModulePublic.sol";
import {CreationCodePublicVault} from
    "../../src/CreationCodePublicVault.sol";
import {CreationCodePrivateVault} from
    "../../src/CreationCodePrivateVault.sol";

import {SetupParams} from "../../src/structs/SManager.sol";

import {IModulePublicRegistry} from
    "../../src/interfaces/IModulePublicRegistry.sol";
import {IModuleRegistry} from
    "../../src/interfaces/IModuleRegistry.sol";
import {IArrakisMetaVaultPublic} from
    "../../src/interfaces/IArrakisMetaVaultPublic.sol";
import {IArrakisMetaVault} from
    "../../src/interfaces/IArrakisMetaVault.sol";
import {IArrakisMetaVaultFactory} from
    "../../src/interfaces/IArrakisMetaVaultFactory.sol";
import {IArrakisPublicVaultRouter} from
    "../../src/interfaces/IArrakisPublicVaultRouter.sol";
import {IRouterSwapExecutor} from
    "../../src/interfaces/IRouterSwapExecutor.sol";
import {IArrakisStandardManager} from
    "../../src/interfaces/IArrakisStandardManager.sol";
import {IValantisSOTModule} from
    "../../src/interfaces/IValantisSOTModule.sol";
import {IOracleWrapper} from "../../src/interfaces/IOracleWrapper.sol";
import {IOwnable} from "../../src/interfaces/IOwnable.sol";
import {IArrakisLPModule} from
    "../../src/interfaces/IArrakisLPModule.sol";

import {
    NATIVE_COIN,
    TEN_PERCENT
} from "../../src/constants/CArrakis.sol";

import {UpgradeableBeacon} from
    "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {SafeCast} from
    "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {SOTBase} from "@valantis/contracts-test/base/SOTBase.t.sol";
import {ERC20} from
    "../../lib/valantis-sot/lib/valantis-core/lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {MockSigner} from
    "@valantis/contracts-test/mocks/MockSigner.sol";
import {SOT, SOTConstructorArgs} from "@valantis/contracts/SOT.sol";
import {SovereignPoolConstructorArgs} from
    "../../lib/valantis-sot/lib/valantis-core/test/base/SovereignPoolBase.t.sol";

import {FullMath} from "@v3-lib-0.8/contracts/FullMath.sol";
import {TickMath} from "@v3-lib-0.8/contracts/TickMath.sol";

// #region mocks.

import {OracleWrapper} from "./mocks/OracleWrapper.sol";

// #endregion mocks.

contract ValantisIntegrationPublicTest is TestWrapper, SOTBase {
    // #region constant properties.

    address public constant WETH =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    // #endregion constant properties.

    address public owner;
    address public pauser;
    address public guardian;
    address public manager;
    address public moduleRegistry;
    address public factory;
    /// @dev that mock arrakis time lock that should be used to upgrade module beacon
    /// and manager implementation.
    address public arrakisTimeLock;
    address public creationCodePublicVault;
    address public creationCodePrivateVault;

    /// @dev the default address that will receive the manager fees.
    address public defaultReceiver;

    address public valantisImplementation;
    address public valantisBeacon;

    address public vault;
    address public executor;
    address public stratAnnouncer;

    // #region mocks.

    address public oracle;
    address public deployer;
    address public signer;

    // #endregion mocks.

    // #region vault infos.

    uint256 public init0;
    uint256 public init1;
    uint24 public maxSlippage;

    // #endregion vault infos.

    SOT public alm;

    function setUp() public override {
        // #region valantis setup.
        (token0, token1) = (ERC20(USDC), ERC20(WETH));

        (feedToken0, feedToken1) = deployChainlinkOracles(18, 6);

        // NOTE : is it needed?
        signer =
            vm.addr(uint256(keccak256(abi.encode("Mock Signer"))));

        // Set initial price to 2000 for token0 and 1 for token1 (Similar to Eth/USDC pair)
        feedToken0.updateAnswer(
            SafeCast.toInt256(FullMath.mulDiv(1e6, 1e18, 2000e6))
        );
        //feedToken0.updateAnswer(2000e18);
        feedToken1.updateAnswer(1e6);

        SovereignPoolConstructorArgs memory poolArgs =
            _generateDefaultConstructorArgs();
        pool = this.deploySovereignPool(poolArgs);

        // #endregion valantis setup.

        owner = vm.addr(uint256(keccak256(abi.encode("Owner"))));
        pauser = vm.addr(uint256(keccak256(abi.encode("Pauser"))));

        defaultReceiver = vm.addr(
            uint256(keccak256(abi.encode("Default Receiver")))
        );

        arrakisTimeLock = vm.addr(
            uint256(keccak256(abi.encode("Arrakis Time Lock")))
        );

        /// @dev we will not use it so we mock it.
        address privateModule =
            vm.addr(uint256(keccak256(abi.encode("Private Module"))));

        executor = vm.addr(uint256(keccak256(abi.encode("Executor"))));
        stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strategy Announcer")))
        );
        deployer = vm.addr(uint256(keccak256(abi.encode("Deployer"))));

        // #region create guardian.

        guardian = _deployGuardian(owner, pauser);

        // #endregion create guardian.

        // #region create manager.

        manager = _deployManager(guardian);

        // #endregion create manager.

        // #region create modules.

        moduleRegistry =
            _deployPublicRegistry(owner, guardian, arrakisTimeLock);

        // #endregion create modules.

        // #region creation code public vault.

        creationCodePublicVault = _deployCreationCodePublicVault();

        // #endregion creation code public vault.

        // #region creation code private vault.

        creationCodePrivateVault = _deployCreationCodePrivateVault();

        // #endregion creation code private vault.

        // #region create factory.

        factory = _deployArrakisMetaVaultFactory(
            owner,
            manager,
            moduleRegistry,
            privateModule,
            creationCodePublicVault,
            creationCodePrivateVault
        );

        // #endregion create factory.

        // #region whitelist a public deployer.

        address[] memory deployers = new address[](1);
        deployers[0] = deployer;

        vm.prank(owner);
        IArrakisMetaVaultFactory(factory).whitelistDeployer(deployers);

        // #endregion whitelist a public deployer.

        // #region initialize manager.

        _initializeManager(owner, defaultReceiver, factory);

        // #endregion initialize manager.

        // #region initialize module registry.

        _initializeModuleRegistry(factory);

        // #endregion initialize module registry.

        // #region create valantis module beacon.

        valantisImplementation =
            _deployValantisImplementation(guardian);
        valantisBeacon = address(
            new UpgradeableBeacon(
                valantisImplementation, arrakisTimeLock
            )
        );

        // #endregion create valantis module beacon.

        // #region whitelist valantis module.

        address[] memory beacons = new address[](1);
        beacons[0] = valantisBeacon;

        vm.prank(owner);
        IModuleRegistry(moduleRegistry).whitelistBeacons(beacons);

        // #endregion whitelist valantis module.

        // #region create valantis pool.

        // #endregion create valantis pool.

        // #region create valantis sot alm.

        // #endregion create valantis sot alm.

        // #region set sot alm.

        // Reserves in the ratio 1: 2000

        // Max volume for token0 ( Eth ) is 100, and for token1 ( USDC ) is 20,000

        // #endregion set sot alm.

        // #region set pool.

        vm.prank(pool.poolManager());
        // pool.setPoolManager();

        // #endregion set pool.

        // #region create oracle wrapper.

        oracle = address(new OracleWrapper());
        OracleWrapper(oracle).setPrice0(
            FullMath.mulDiv(1e6, 1e18, 2000e6)
        );
        OracleWrapper(oracle).setPrice1(2000e6);

        // #endregion create oracle wrapper.

        // #region create public vault.

        bytes32 salt = keccak256(abi.encode("Public vault salt"));
        init0 = 2000e6;
        init1 = 1e18;
        maxSlippage = TEN_PERCENT;

        bytes memory moduleCreationPayload = abi.encodeWithSelector(
            IValantisSOTModule.initialize.selector,
            address(pool),
            init0,
            init1,
            maxSlippage,
            oracle
        );
        bytes memory initManagementPayload = abi.encode(
            IOracleWrapper(oracle),
            TEN_PERCENT,
            uint256(60),
            executor,
            stratAnnouncer,
            maxSlippage
        );

        vm.prank(deployer);
        vault = IArrakisMetaVaultFactory(factory).deployPublicVault(
            salt,
            address(token0),
            address(token1),
            owner,
            valantisBeacon,
            moduleCreationPayload,
            initManagementPayload
        );

        // #endregion create public vault.

        address m = address(IArrakisMetaVault(vault).module());

        vm.prank(pool.poolManager());
        pool.setPoolManager(m);

        // #region valantis mock.

        int24 tick = TickMath.getTickAtSqrtRatio(
            1_771_595_571_142_957_102_904_975_518_859_264
        );

        SOTConstructorArgs memory args = SOTConstructorArgs({
            pool: address(pool),
            manager: address(this),
            signer: signer,
            liquidityProvider: m,
            feedToken0: address(feedToken0),
            feedToken1: address(feedToken1),
            sqrtSpotPriceX96: 1_771_595_571_142_957_102_904_975_518_859_264,
            sqrtPriceLowX96: TickMath.getSqrtRatioAtTick(tick - 100),
            sqrtPriceHighX96: TickMath.getSqrtRatioAtTick(tick + 100),
            maxDelay: 9 minutes,
            maxOracleUpdateDurationFeed0: 10 minutes,
            maxOracleUpdateDurationFeed1: 10 minutes,
            solverMaxDiscountBips: 200, // 2%
            maxOracleDeviationBound: 5000, // 50%
            minAMMFeeGrowthInPips: 100,
            maxAMMFeeGrowthInPips: 10_000,
            minAMMFee: 1 // 0.01%
        });

        vm.startPrank(pool.poolManager());
        alm = new SOT(args);
        pool.setALM(address(alm));
        pool.setSwapFeeModule(address(alm));
        vm.stopPrank();

        _addToContractsToApprove(address(pool));
        _addToContractsToApprove(address(alm));

        vm.prank(IOwnable(vault).owner());
        IValantisSOTModule(m).setALMAndManagerFees(address(alm));

        vm.prank(address(this));
        alm.setMaxTokenVolumes(100e18, 20_000e18);
        alm.setMaxAllowedQuotes(2);

        // #endregion valantis mock.

        uint160 sqrtSpotPriceX96 = alm.getSqrtOraclePriceX96();

        uint256 currentPrice = FullMath.mulDiv(
            FullMath.mulDiv(
                sqrtSpotPriceX96, sqrtSpotPriceX96, 1 << 64
            ),
            10 ** 6,
            1 << 128
        );

        (sqrtSpotPriceX96,,) = alm.getAMMState();

        currentPrice = FullMath.mulDiv(
            FullMath.mulDiv(
                sqrtSpotPriceX96, sqrtSpotPriceX96, 1 << 64
            ),
            10 ** 6,
            1 << 128
        );
    }

    // #region tests.

    function test_mint() public {
        address user = vm.addr(uint256(keccak256(abi.encode("User"))));
        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));

        deal(address(token0), user, init0);
        deal(address(token1), user, init1);

        address m = address(IArrakisMetaVault(vault).module());

        vm.startPrank(user);
        token0.approve(m, init0);
        token1.approve(m, init1);

        IArrakisMetaVaultPublic(vault).mint(1e18, receiver);
        vm.stopPrank();
    }

    function test_burn() public {
        // #region mint.

        address user = vm.addr(uint256(keccak256(abi.encode("User"))));
        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));

        deal(address(token0), user, init0);
        deal(address(token1), user, init1);

        address m = address(IArrakisMetaVault(vault).module());

        vm.startPrank(user);
        token0.approve(m, init0);
        token1.approve(m, init1);

        IArrakisMetaVaultPublic(vault).mint(1e18, receiver);
        vm.stopPrank();

        // #endregion mint.

        // #region burn.

        vm.startPrank(receiver);
        IArrakisMetaVaultPublic(vault).burn(1e18, user);

        // #endregion burn.
    }

    function test_withdrawManagerBalance() public {
        // #region mint.

        address user = vm.addr(uint256(keccak256(abi.encode("User"))));
        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));

        deal(address(token0), user, init0);
        deal(address(token1), user, init1);

        address m = address(IArrakisMetaVault(vault).module());

        vm.startPrank(user);
        token0.approve(m, init0);
        token1.approve(m, init1);

        IArrakisMetaVaultPublic(vault).mint(1e18, receiver);
        vm.stopPrank();

        // #endregion mint.

        IArrakisLPModule(m).withdrawManagerBalance();
    }

    function test_getManagerValues() public {
        // #region mint.

        address user = vm.addr(uint256(keccak256(abi.encode("User"))));
        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));

        deal(address(token0), user, init0);
        deal(address(token1), user, init1);

        address m = address(IArrakisMetaVault(vault).module());

        vm.startPrank(user);
        token0.approve(m, init0);
        token1.approve(m, init1);

        IArrakisMetaVaultPublic(vault).mint(1e18, receiver);
        vm.stopPrank();

        // #endregion mint.

        // console.logUint(IArrakisLPModule(m).managerBalance0());
        // console.logUint(IArrakisLPModule(m).managerBalance1());
        // console.logUint(IArrakisLPModule(m).managerFeePIPS());
    }

    function test_getReservers() public {
        // #region mint.

        address user = vm.addr(uint256(keccak256(abi.encode("User"))));
        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));

        deal(address(token0), user, init0);
        deal(address(token1), user, init1);

        address m = address(IArrakisMetaVault(vault).module());

        vm.startPrank(user);
        token0.approve(m, init0);
        token1.approve(m, init1);

        IArrakisMetaVaultPublic(vault).mint(1e18, receiver);
        vm.stopPrank();

        // #endregion mint.

        (uint256 amount0, uint256 amount1) =
            IArrakisLPModule(m).totalUnderlying();
        // console.logUint(amount0);
        // console.logUint(amount1);

        (amount0, amount1) = IArrakisLPModule(m)
            .totalUnderlyingAtPrice(TickMath.getSqrtRatioAtTick(10));

        // console.logUint(amount0);
        // console.logUint(amount1);
    }

    function test_validateRebalance() public {
        // #region mint.

        address user = vm.addr(uint256(keccak256(abi.encode("User"))));
        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));

        deal(address(token0), user, init0);
        deal(address(token1), user, init1);

        address m = address(IArrakisMetaVault(vault).module());

        vm.startPrank(user);
        token0.approve(m, init0);
        token1.approve(m, init1);

        IArrakisMetaVaultPublic(vault).mint(1e18, receiver);
        vm.stopPrank();

        // #endregion mint.

        IArrakisLPModule(m).validateRebalance(
            IOracleWrapper(oracle), TEN_PERCENT
        );
    }

    function test_swap() public {
        // #region mint.

        address user = vm.addr(uint256(keccak256(abi.encode("User"))));
        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));

        deal(address(token0), user, init0);
        deal(address(token1), user, init1);

        address m = address(IArrakisMetaVault(vault).module());

        vm.startPrank(user);
        token0.approve(m, init0);
        token1.approve(m, init1);

        IArrakisMetaVaultPublic(vault).mint(1e18, receiver);
        vm.stopPrank();

        // #endregion mint.

        (uint160 sqrtSpotPriceX96,,) = alm.getAMMState();

        bool zeroForOne = true; // USDC -> WETH.
        uint256 expectedMinReturn = 0.5 ether;
        uint256 amountIn = 1000e6;
        address router = address(this);

        uint160 expectedSqrtSpotPriceUpperX96 =
            1_771_595_571_142_957_102_904_975_518_859_264;
        uint160 expectedSqrtSpotPriceLowerX96 =
            1_771_595_571_142_957_102_904_975_518_859_264;
        bytes memory payload =
            abi.encodeWithSelector(this.swap.selector);

        bytes memory data = abi.encodeWithSelector(
            IValantisSOTModule.swap.selector,
            zeroForOne,
            expectedMinReturn,
            amountIn,
            router,
            expectedSqrtSpotPriceUpperX96,
            expectedSqrtSpotPriceLowerX96,
            payload
        );

        bytes[] memory datas = new bytes[](1);
        datas[0] = data;

        vm.prank(executor);
        IArrakisStandardManager(manager).rebalance(vault, datas);
    }

    function test_setPriceBounds() public {
        // #region mint.

        address user = vm.addr(uint256(keccak256(abi.encode("User"))));
        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));

        deal(address(token0), user, init0);
        deal(address(token1), user, init1);

        address m = address(IArrakisMetaVault(vault).module());

        vm.startPrank(user);
        token0.approve(m, init0);
        token1.approve(m, init1);

        IArrakisMetaVaultPublic(vault).mint(1e18, receiver);
        vm.stopPrank();

        // #endregion mint.

        uint160 sqrtPriceLowX96 = TickMath.getSqrtRatioAtTick(
            TickMath.getTickAtSqrtRatio(
                1_771_595_571_142_957_102_904_975_518_859_264
            ) - 10
        );
        uint160 sqrtPriceHighX96 = TickMath.getSqrtRatioAtTick(
            TickMath.getTickAtSqrtRatio(
                1_771_595_571_142_957_102_904_975_518_859_264
            ) + 10
        );
        uint160 expectedSqrtSpotPriceUpperX96 =
            1_771_595_571_142_957_102_904_975_518_859_264;
        uint160 expectedSqrtSpotPriceLowerX96 =
            1_771_595_571_142_957_102_904_975_518_859_264;

        bytes memory data = abi.encodeWithSelector(
            IValantisSOTModule.setPriceBounds.selector,
            sqrtPriceLowX96,
            sqrtPriceHighX96,
            expectedSqrtSpotPriceUpperX96,
            expectedSqrtSpotPriceLowerX96
        );

        bytes[] memory datas = new bytes[](1);
        datas[0] = data;

        vm.prank(executor);
        IArrakisStandardManager(manager).rebalance(vault, datas);
    }

    // #endregion tests.

    // #region internal functions.

    function _deployGuardian(
        address owner_,
        address pauser_
    ) internal returns (address guardian) {
        return address(new Guardian(owner_, pauser_));
    }

    function _deployManager(address guardian_)
        internal
        returns (address)
    {
        /// @dev default fee pips is set at 10%

        return address(
            new ArrakisStandardManager(
                TEN_PERCENT, NATIVE_COIN, 18, guardian_
            )
        );
    }

    function _deployPublicRegistry(
        address owner_,
        address guardian_,
        address admin_
    ) internal returns (address) {
        return address(
            new ModulePublicRegistry(owner, guardian_, admin_)
        );
    }

    function _deployValantisImplementation(address guardian_)
        internal
        returns (address)
    {
        return address(new ValantisModulePublic(guardian_));
    }

    function _deployCreationCodePublicVault()
        internal
        returns (address)
    {
        return address(new CreationCodePublicVault());
    }

    function _deployCreationCodePrivateVault()
        internal
        returns (address)
    {
        return address(new CreationCodePrivateVault());
    }

    function _deployArrakisMetaVaultFactory(
        address owner_,
        address manager_,
        address modulePublicRegistry_,
        address modulePrivateRegistry_,
        address creationCodePublicVault_,
        address creationCodePrivateVault_
    ) internal returns (address) {
        return address(
            new ArrakisMetaVaultFactory(
                owner_,
                manager_,
                modulePublicRegistry_,
                modulePrivateRegistry_,
                creationCodePublicVault_,
                creationCodePrivateVault_
            )
        );
    }

    /// @dev should be called after creation of factory contract.
    function _initializeManager(
        address owner_,
        address defaultReceiver_,
        address factory_
    ) internal {
        IArrakisStandardManager(manager).initialize(
            owner, defaultReceiver_, factory_
        );
    }

    /// @dev should be called after creation of factory contract.
    function _initializeModuleRegistry(address factory_) internal {
        IModuleRegistry(moduleRegistry).initialize(factory_);
    }

    // #endregion internal functions.

    // #region swap router mock.

    function swap() external {
        ERC20(USDC).transferFrom(msg.sender, address(this), 1000e6);
        deal(WETH, msg.sender, 1.5 ether);
    }

    // #endregion swap router mock.
}
