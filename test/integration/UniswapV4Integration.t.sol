// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// #region foundry.
import {TestWrapper} from "../utils/TestWrapper.sol";
import {console} from "forge-std/console.sol";
// #endregion foundry.

import {UniV4StandardModule} from
    "../../src/modules/UniV4StandardModule.sol";
import {BunkerModule} from "../../src/modules/BunkerModule.sol";

// #region interfaces.

import {IArrakisMetaVaultFactory} from
    "../../src/interfaces/IArrakisMetaVaultFactory.sol";
import {IArrakisPrivateVaultRouter} from
    "../../src/interfaces/IArrakisPrivateVaultRouter.sol";
import {IArrakisPublicVaultRouter} from
    "../../src/interfaces/IArrakisPublicVaultRouter.sol";
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

// #endregion uniswap v4.

// #region valantis mocks.

// #endregion valantis mocks.

contract UniswapV4IntegrationTest is TestWrapper {
    using SafeERC20 for IERC20Metadata;

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
    address public constant router =
        0x72aa2C8e6B14F30131081401Fa999fC964A66041;
    address public constant routerResolver =
        0xC6c53369c36D6b4f4A6c195441Fe2d33149FB265;
    address public constant valantisModuleBeacon =
        0xE973Cf1e347EcF26232A95dBCc862AA488b0351b;
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
    }

    // #region internal functions.

    function _setup() internal {
        deployer = vm.addr(uint256(keccak256(abi.encode("Deployer"))));
        // #region whitelist a deployer.

        address factoryOwner = IOwnable(factory).owner();

        address[] memory deployers = new address[](1);
        deployers[0] = deployer;

        console.log("Factory Owner : %d", factoryOwner);

        vm.prank(factoryOwner);
        IArrakisMetaVaultFactory(factory).whitelistDeployer(deployers);

        // #endregion whitelist a deployer.

        // #region uniswap setup.

        poolManager = _deployPoolManager();

        // #endregion uniswap setup.

        // #region create bunker module.

        _deployBunkerModule();

        // #endregion create bunker module.

        // #region create an uniswap standard module.

        _deployUniswapStandardModule(poolManager);

        // #endregion create an uniswap standard module.

        address[] memory beacons = new address[](2);
        beacons[0] = bunkerBeacon;
        beacons[1] = uniswapStandardModuleBeacon;

        address registryOwner = IOwnable(publicRegistry).owner();

        console.log("Registry Owner : %d", registryOwner);
        vm.startPrank(registryOwner);

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
    }

    function _deployUniswapStandardModule(
        address poolManager_
    ) internal {
        // #region create uniswap standard module.

        uniswapStandardModuleImplementation =
            address(new UniV4StandardModule(poolManager, guardian));
        uniswapStandardModuleBeacon = address(
            new UpgradeableBeacon(uniswapStandardModuleImplementation)
        );

        UpgradeableBeacon(uniswapStandardModuleBeacon)
            .transferOwnership(arrakisTimeLock);

        // #endregion create uniswap standard module.
    }

    function _setupETHUSDCVault() internal returns (address vault) {}

    function _setupWETHUSDCVaultForExisting() internal {}

    // #endregion internal functions.
}
