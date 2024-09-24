// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// #region foundry.
import {TestWrapper} from "../utils/TestWrapper.sol";
import {console} from "forge-std/console.sol";
// #endregion foundry.

import {UniV4StandardModulePublic} from
    "../../src/modules/UniV4StandardModulePublic.sol";
import {BunkerModule} from "../../src/modules/BunkerModule.sol";
import {ArrakisPublicVaultRouterV2} from
    "../../src/ArrakisPublicVaultRouterV2.sol";
import {RouterSwapExecutor} from "../../src/RouterSwapExecutor.sol";
import {UniV4StandardModuleResolver} from
    "../../src/modules/resolvers/UniV4StandardModuleResolver.sol";
import {
    NATIVE_COIN,
    TEN_PERCENT
} from "../../src/constants/CArrakis.sol";

// #region interfaces.

import {IArrakisMetaVaultFactory} from
    "../../src/interfaces/IArrakisMetaVaultFactory.sol";
import {IArrakisPrivateVaultRouter} from
    "../../src/interfaces/IArrakisPrivateVaultRouter.sol";
import {IArrakisPublicVaultRouter} from
    "../../src/interfaces/IArrakisPublicVaultRouter.sol";
import {IArrakisPublicVaultRouterV2} from
    "../../src/interfaces/IArrakisPublicVaultRouterV2.sol";
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
import {IUniV4StandardModule} from
    "../../src/interfaces/IUniV4StandardModule.sol";
import {IOracleWrapper} from "../../src/interfaces/IOracleWrapper.sol";

// #endregion interfaces.

// #region openzeppelin.

import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {UpgradeableBeacon} from
    "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

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

// #endregion uniswap v4.

// #region valantis mocks.

// #endregion valantis mocks.

contract UniswapV4IntegrationTest is TestWrapper {
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
    address public constant valantisModuleBeacon =
        0xE973Cf1e347EcF26232A95dBCc862AA488b0351b;
    address public constant permit2 =
        0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address public constant weth =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    // #endregion arrakis modular contracts.

    address public owner;

    address public bunkerImplementation;
    address public bunkerBeacon;

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

    // #region uniswap.

    address public poolManager;

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

        // #endregion setup.

        _setup();

        // #region create a uniswap v4 pool.

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

        // #endregion create a uniswap v4 pool.

        // #region create a vault.

        bytes32 salt =
            keccak256(abi.encode("Public vault Univ4 salt"));
        init0 = 2000e6;
        init1 = 1e18;
        maxSlippage = 10_000;

        bytes memory moduleCreationPayload = abi.encodeWithSelector(
            IUniV4StandardModule.initialize.selector,
            init0,
            init1,
            false,
            poolKey
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
    }

    // #region uniswap v4 callback function.

    function unlockCallback(
        bytes calldata data
    ) public returns (bytes memory) {
        uint256 typeOfLockAcquired = abi.decode(data, (uint256));

        if (typeOfLockAcquired == 0) {
            IPoolManager(poolManager).initialize(
                poolKey, sqrtPriceX96, ""
            );
        }
    }

    // #endregion uniswap v4 callback function.

    // #region test.

    function test_mint() public {
        
    }

    // #endregion test.

    // #region internal functions.

    function _setup() internal {
        deployer = vm.addr(uint256(keccak256(abi.encode("Deployer"))));
        // #region whitelist a deployer.

        address factoryOwner = IOwnable(factory).owner();

        address[] memory deployers = new address[](1);
        deployers[0] = deployer;

        vm.prank(factoryOwner);
        IArrakisMetaVaultFactory(factory).whitelistDeployer(deployers);

        // #endregion whitelist a deployer.

        // #region uniswap setup.

        poolManager = _deployPoolManager();

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

        uniV4resolver =
            _deployUniV4StandardModuleResolver(poolManager);

        // #endregion create resolver.

        // #region initialize router.

        vm.prank(owner);

        ArrakisPublicVaultRouterV2(payable(router)).updateSwapExecutor(
            swapExecutor
        );

        // #endregion initialize router.

        // #region whitelist resolver.

        address[] memory resolvers = new address[](1);
        resolvers[0] = uniV4resolver;

        vm.prank(owner);
        IArrakisPublicVaultRouterV2(router).whitelistResolvers(
            resolvers
        );

        // #endregion whitelist resolver.

        // #region create an uniswap standard module.

        _deployUniswapStandardModule(poolManager);

        // #endregion create an uniswap standard module.

        address[] memory beacons = new address[](2);
        beacons[0] = bunkerBeacon;
        beacons[1] = uniswapStandardModuleBeacon;

        vm.startPrank(IOwnable(publicRegistry).owner());

        IModuleRegistry(publicRegistry).whitelistBeacons(beacons);
        IModuleRegistry(privateRegistry).whitelistBeacons(beacons);

        vm.stopPrank();
    }

    function _deployPoolManager() internal returns (address pm) {
        pm = address(new PoolManager());
    }

    function _deployBunkerModule() internal {
        bunkerImplementation = address(new BunkerModule(guardian));

        bunkerBeacon =
            address(new UpgradeableBeacon(bunkerImplementation));

        UpgradeableBeacon(bunkerBeacon).transferOwnership(
            arrakisTimeLock
        );
    }

    function _deployUniswapStandardModule(
        address poolManager_
    ) internal {
        // #region create uniswap standard module.

        uniswapStandardModuleImplementation =
            address(new UniV4StandardModulePublic(poolManager, guardian));
        uniswapStandardModuleBeacon = address(
            new UpgradeableBeacon(uniswapStandardModuleImplementation)
        );

        UpgradeableBeacon(uniswapStandardModuleBeacon)
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

    function _deployUniV4StandardModuleResolver(
        address poolManager
    ) internal returns (address resolver) {
        return address(new UniV4StandardModuleResolver(poolManager));
    }

    function _setupETHUSDCVault() internal returns (address vault) {}

    function _setupWETHUSDCVaultForExisting() internal {}

    // #endregion internal functions.
}
