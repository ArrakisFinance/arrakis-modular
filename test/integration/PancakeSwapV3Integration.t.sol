// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// #region foundry.
import {TestWrapper} from "../utils/TestWrapper.sol";
import {console} from "forge-std/console.sol";
// #endregion foundry.

import {BunkerModule} from "../../src/modules/BunkerModule.sol";
import {
    NATIVE_COIN,
    TEN_PERCENT
} from "../../src/constants/CArrakis.sol";

// #region interfaces.

import {IArrakisMetaVault} from
    "../../src/interfaces/IArrakisMetaVault.sol";
import {IArrakisMetaVaultFactory} from
    "../../src/interfaces/IArrakisMetaVaultFactory.sol";
import {PancakeSwapV3StandardModulePrivate} from
    "../../src/modules/PancakeSwapV3StandardModulePrivate.sol";
import {IOwnable} from "../../src/interfaces/IOwnable.sol";
import {IOracleWrapper} from "../../src/interfaces/IOracleWrapper.sol";
import {IArrakisStandardManager} from
    "../../src/interfaces/IArrakisStandardManager.sol";
import {IMasterChefV3} from "../../src/interfaces/IMasterChefV3.sol";

// #endregion interfaces.

// #region openzeppelin.

import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// #endregion openzeppelin.

// #region mocks.

import {OracleWrapper} from "./mocks/OracleWrapper.sol";

// #endregion mocks.

contract PancakeSwapV3IntegrationTest is TestWrapper {
    // #region constant tokens.

    address public constant WETH =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDT =
        0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public constant AAVE =
        0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9;

    // #endregion constant tokens.

    // #region pancake swap v3.
    address public constant pancakePool =
        0x1445F32D1A74872bA41f3D8cF4022E9996120b31;
    address public constant pancakeV3Factory =
        0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865;
    address public constant masterChef =
        0x556B9306565093C855AEA9AE92A594704c2Cd59e;
    address public constant nftPositionManager =
        0x46A15B0b27311cedF172AB29E4f4766fbE7F4364;
    // #endregion pancake swap v3.

    // #region arrakis smart contracts.
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
    address public constant bunkerBeacon =
        0xFf0474792DEe71935a0CeF1306D93fC1DCF47BD9;

    // #endregion arrakis smart contracts.

    address public constant permit2 =
        0x000000000022D473030F116dDEE9F6B43aC78BA3;

    address public owner;

    address public pancakeSwapStandardModuleImplementation;
    address public pancakeSwapStandardModuleBeacon;

    address public privateModule;
    address public vault;
    address public executor;
    address public stratAnnouncer;

    address public oracle;
    address public deployer;

    // #region vault infos.

    uint256 public init0;
    uint256 public init1;
    uint24 public maxSlippage;

    // #endregion vault infos.

    IERC20Metadata public token0;
    IERC20Metadata public token1;

    function setUp() public {
        // #region reset fork.

        _reset(vm.envString("ETH_RPC_URL"), 22_792_200);

        // #endregion reset fork.

        // #region setup.

        owner = vm.addr(uint256(keccak256(abi.encode("Owner"))));
        executor = vm.addr(uint256(keccak256(abi.encode("Executor"))));
        stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strategy Announcer")))
        );
        deployer = vm.addr(uint256(keccak256(abi.encode("Deployer"))));

        (token0, token1) =
            (IERC20Metadata(USDC), IERC20Metadata(WETH));

        // #endregion setup.

        // #region create an oracle.

        oracle = address(new OracleWrapper());

        // #endregion create an oracle.

        _setup();
    }

    // #region helper functions.

    function _setup() internal {
        // #region create an pancake swap v3 integration.

        // pancakeSwapStandardModuleImplementation = address(
        //     new PancakeSwapV3StandardModulePrivate(
        //         guardian,

        //     )
        // )

        // #endregion create an pancake swap v3 integration.
    }

    // #endregion helper functions.
}
