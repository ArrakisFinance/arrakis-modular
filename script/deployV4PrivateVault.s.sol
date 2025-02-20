// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";
import {CreateXScript} from "./deployment/CreateXScript.sol";

import {IPoolManager} from
    "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {
    PoolKey, Currency
} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {CurrencyLibrary} from
    "@uniswap/v4-core/src/types/Currency.sol";
import {
    PoolId,
    PoolIdLibrary
} from "@uniswap/v4-core/src/types/PoolId.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";

import {NATIVE_COIN} from "../src/constants/CArrakis.sol";
import {UniV4Oracle} from "../src/oracles/UniV4Oracle.sol";
import {IOracleWrapper} from "../src/interfaces/IOracleWrapper.sol";
import {IUniV4StandardModule} from
    "../src/interfaces/IUniV4StandardModule.sol";
import {IArrakisMetaVaultFactory} from
    "../src/interfaces/IArrakisMetaVaultFactory.sol";

// IMPORTANT !!! Fill in / check these sensitive varaibles before running script !!!

address constant token0 = address(0);
address constant token1 = address(0);
uint24 constant fee = 0;
int24 constant tickSpacing = 0;
address constant hooks = address(0);
int24 constant tick = 0;
uint160 constant sqrtPrice = 0;

bool constant isInversed = false;

bytes32 constant salt = keccak256(abi.encode("Salt To Define"));
address constant vaultOwner = address(0);
uint256 constant init0 = 0;
uint256 constant init1 = 0;
uint24 constant maxSlippage = 0;

uint24 constant maxDeviation = 0;
uint256 constant cooldownPeriod = 0;
address constant executor = address(0);
address constant stratAnnouncer = address(0);

address constant factory = 0x820FB8127a689327C863de8433278d6181123982;

contract DeployV4PrivateVault is CreateXScript {
    using PoolIdLibrary for PoolKey;

    function setUp() public {}

    function run() public {
        address poolManager = getPoolManager();

        address uniV4PrivateUpgradeableBeacon = getUpgradeableBeacon();

        vm.startBroadcast();

        console.log("Deployer : ");
        console.logAddress(msg.sender);

        // #region create uni v4 pool.

        PoolKey memory poolKey;

        if (isInversed) {
            poolKey = PoolKey({
                currency0: CurrencyLibrary.ADDRESS_ZERO,
                currency1: Currency.wrap(token0),
                fee: fee,
                tickSpacing: tickSpacing,
                hooks: IHooks(hooks)
            });
        } else {
            poolKey = PoolKey({
                currency0: CurrencyLibrary.ADDRESS_ZERO,
                currency1: Currency.wrap(token1),
                fee: fee,
                tickSpacing: tickSpacing,
                hooks: IHooks(hooks)
            });
        }

        IPoolManager(poolManager).initialize(poolKey, sqrtPrice);

        PoolId poolId = poolKey.toId();

        console.log("Pool Id : ");
        console.logBytes32(PoolId.unwrap(poolId));

        // #endregion create uni v4 pool.

        // #region create uni V4 oracle.

        address uniV4Oracle =
            address(new UniV4Oracle(poolKey, poolManager, isInversed));

        console.log("Uni V4 Oracle : ");
        console.logAddress(uniV4Oracle);

        // #endregion create uni V4 oracle.

        // #region create private vault.

        bytes memory moduleCreationPayload = abi.encodeWithSelector(
            IUniV4StandardModule.initialize.selector,
            init0,
            init1,
            isInversed,
            poolKey,
            IOracleWrapper(uniV4Oracle),
            maxSlippage
        );
        bytes memory initManagementPayload = abi.encode(
            IOracleWrapper(uniV4Oracle),
            maxDeviation,
            cooldownPeriod,
            executor,
            stratAnnouncer,
            maxSlippage
        );

        address vault = IArrakisMetaVaultFactory(factory)
            .deployPrivateVault(
            salt,
            token0,
            token1,
            vaultOwner,
            uniV4PrivateUpgradeableBeacon,
            moduleCreationPayload,
            initManagementPayload
        );

        console.logString("Uniswap Private Vault Address : ");
        console.logAddress(vault);

        // #endregion create private vault.

        vm.stopBroadcast();
    }

    function getUpgradeableBeacon() internal view returns (address) {
        uint256 chainId = block.chainid;

        // mainnet
        if (chainId == 1) {
            return 0x022a0C7dc85Fc3fF81f9f8Ef65Ae2813A062F556;
        }
        // polygon
        else if (chainId == 137) {
            return 0xFb4e25800b77BcD09227729FFCC145685797f408;
        }
        // optimism
        else if (chainId == 10) {
            return 0x413fc8E6F0B95D1f45de01b17e9441ec41eD01AB;
        }
        // sepolia
        else if (chainId == 11_155_111) {
            return 0xC0b7FaC163566A768B4F30d06fD4b08bb6b987F0;
        }
        // base
        else if (chainId == 8453) {
            return 0x97d42db1B71B1c9a811a73ce3505Ac00f9f6e5fB;
        }
        // Ink
        else if (chainId == 57_073) {
            return 0xCc8989978668ad377369C0cC720192377a6006e3;
        }
        // Unichain
        else if (chainId == 130) {
            return 0xCc8989978668ad377369C0cC720192377a6006e3;
        }
        // default
        else {
            revert("Not supported network!");
        }
    }

    function getPoolManager() public view returns (address) {
        uint256 chainId = block.chainid;

        // mainnet
        if (chainId == 1) {
            return 0x000000000004444c5dc75cB358380D2e3dE08A90;
        }
        // polygon
        else if (chainId == 137) {
            return 0x67366782805870060151383F4BbFF9daB53e5cD6;
        }
        // optimism
        else if (chainId == 10) {
            return 0x9a13F98Cb987694C9F086b1F5eB990EeA8264Ec3;
        }
        // sepolia
        else if (chainId == 11_155_111) {
            return 0xE03A1074c86CFeDd5C142C4F04F1a1536e203543;
        }
        // base
        else if (chainId == 8453) {
            return 0x498581fF718922c3f8e6A244956aF099B2652b2b;
        }
        // Ink
        else if (chainId == 57_073) {
            return 0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32;
        }
        // Unichain
        else if (chainId == 130) {
            return 0x1F98400000000000000000000000000000000004;
        }
    }
}
