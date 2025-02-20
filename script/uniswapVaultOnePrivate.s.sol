// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {IArrakisMetaVaultFactory} from
    "../src/interfaces/IArrakisMetaVaultFactory.sol";
import {IUniV4StandardModule} from
    "../src/interfaces/IUniV4StandardModule.sol";
import {IOracleWrapper} from "../src/interfaces/IOracleWrapper.sol";
import {PIPS, NATIVE_COIN} from "../src/constants/CArrakis.sol";

import {
    PoolKey, Currency
} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {
    CurrencyLibrary
} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";

/// @dev before this script we should whitelist the deployer as public vault deployer using the multisig
/// on the factory side.

bytes32 constant salt =
    keccak256(abi.encode("Salt ETH/USDC Uni vault Private Test 9"));
address constant token0 = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
address constant token1 = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
address constant vaultOwner =
    0x4C5FD345EAd47e46aA7675a4f4AE0d00Bb44650C;

uint256 constant init0 = 2600e6;
uint256 constant init1 = 1e8;
uint24 constant maxSlippage = PIPS / 50;

uint24 constant maxDeviation = PIPS / 50;
uint256 constant cooldownPeriod = 60;
address constant executor = 0xe012b59a8fC2D18e2C8943106a05C2702640440B;
address constant stratAnnouncer =
    0x4C5FD345EAd47e46aA7675a4f4AE0d00Bb44650C;

address constant uniV4PrivateUpgradeableBeacon =
    0xC0b7FaC163566A768B4F30d06fD4b08bb6b987F0;
address constant factory = 0x820FB8127a689327C863de8433278d6181123982;
bool constant isInversed = false;
address constant oracle = 0x2f7989F3C6E3462e028a4Fa23F570805F1EE9fEb;

// #region pool key.
uint24 constant fee = 1000;
int24 constant tickSpacing = 60;
address constant hooks = address(0);
// #endregion pool key.

// oracle : 0x2f7989F3C6E3462e028a4Fa23F570805F1EE9fEb 

contract UniswapVaultOnePrivate is Script {
    function setUp() public {}

    function run() public {

        console.logString("Deployer : ");
        console.logAddress(msg.sender);

        vm.startBroadcast();

        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: fee,
            tickSpacing: tickSpacing,
            hooks: IHooks(hooks)
        });

        bytes memory moduleCreationPayload = abi.encodeWithSelector(
            IUniV4StandardModule.initialize.selector,
            init0,
            init1,
            isInversed,
            poolKey,
            IOracleWrapper(oracle),
            maxSlippage
        );
        bytes memory initManagementPayload = abi.encode(
            IOracleWrapper(oracle),
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

        vm.stopBroadcast();
    }
}
