// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {Guardian} from "../src/Guardian.sol";
import {ArrakisStandardManager} from
    "../src/ArrakisStandardManager.sol";
import {ModulePublicRegistry} from "../src/ModulePublicRegistry.sol";
import {ModulePrivateRegistry} from "../src/ModulePrivateRegistry.sol";
import {ArrakisMetaVaultFactory} from
    "../src/ArrakisMetaVaultFactory.sol";
import {RouterSwapExecutor} from "../src/RouterSwapExecutor.sol";
import {ArrakisPublicVaultRouter} from
    "../src/ArrakisPublicVaultRouter.sol";
import {CreationCodePublicVault} from
    "../src/CreationCodePublicVault.sol";
import {CreationCodePrivateVault} from
    "../src/CreationCodePrivateVault.sol";

import {NATIVE_COIN, PIPS} from "../src/constants/CArrakis.sol";

import {TimelockController} from
    "@openzeppelin/contracts/governance/TimelockController.sol";
import {ProxyAdmin} from
    "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {Initializable} from
    "@openzeppelin/contracts/proxy/utils/Initializable.sol";

// #region value to set.

// #region guardian params.

address constant guardianOwner =
    0x969cA3961FCeaFd3Cb3C1CA9ecdd475babcD704D;
address constant guardianPauser =
    0x969cA3961FCeaFd3Cb3C1CA9ecdd475babcD704D;

// #endregion guardian params.

// #region arrakis timeLock.

uint256 constant minDelay = 0 days;
address constant proposer = 0x969cA3961FCeaFd3Cb3C1CA9ecdd475babcD704D;
address constant executor = 0x969cA3961FCeaFd3Cb3C1CA9ecdd475babcD704D;
address constant timeLockAdmin =
    0x969cA3961FCeaFd3Cb3C1CA9ecdd475babcD704D;

// #endregion arrakis timeLock.

// #region arrakis standard manager.

uint256 constant defaultFeePIPS = PIPS / 100;
address constant nativeToken = NATIVE_COIN;
uint8 constant nativeTokenDecimals = 18;
address constant managerOwner =
    0x969cA3961FCeaFd3Cb3C1CA9ecdd475babcD704D;

// #endregion arrakis standard manager.

// #region public module registry.

address constant publicModuleRegistryOwner =
    0x969cA3961FCeaFd3Cb3C1CA9ecdd475babcD704D;

// #endregion public module registry.

// #region private module registry.

address constant privateModuleRegistryOwner =
    0x969cA3961FCeaFd3Cb3C1CA9ecdd475babcD704D;

// #endregion private module registry.

// #region factory.

address constant factoryOwner =
    0x969cA3961FCeaFd3Cb3C1CA9ecdd475babcD704D;

// #endregion factory.

// #region router.

address constant permit2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
address constant routerOwner =
    0x969cA3961FCeaFd3Cb3C1CA9ecdd475babcD704D;
address constant weth = 0x6A023CCd1ff6F2045C3309768eAd9E68F978f6e1;

// #endregion router.

/// @dev default address that will receiver tokens earned by manager.
address constant defaultReceiver =
    0x969cA3961FCeaFd3Cb3C1CA9ecdd475babcD704D;

// #endregion value to set.

contract DeployStepOne is Script {
    address public guardian;
    address public arrakisTimeLock;
    address public manager;
    address public publicRegistry;
    address public privateRegistry;
    address public creationCodePublicVault;
    address public creationCodePrivateVault;
    address public factory;
    address public router;
    address public routerExecutor;

    function setUp() public {}

    function run() public {
        uint256 privateKey = vm.envUint("PK_TEST");

        address account = vm.addr(privateKey);

        console.logAddress(account);

        vm.startBroadcast(privateKey);

        _deployGuardian();
        _deployArrakisTimeLock();
        _deployArrakisStandardManager(guardian, arrakisTimeLock);
        _deployModuleRegistryPublic(guardian, arrakisTimeLock);
        _deployModuleRegistryPrivate(guardian, arrakisTimeLock);
        _deployCreationCodePublicVault();
        _deployCreationCodePrivateVault();
        _deployFactory(
            manager,
            publicRegistry,
            privateRegistry,
            creationCodePublicVault,
            creationCodePrivateVault
        );
        _deployRouter(factory);
        _deployRouterExecutor(router);

        _initializeManager(factory);
        _initializePublicModuleRegistry(factory);
        _initializePrivateModuleRegistry(factory);
        // _initializeRouter(routerExecutor);

        vm.stopBroadcast();
    }

    // #region deploy guardian.

    function _deployGuardian() internal returns (address) {
        guardian =
            address(new Guardian(guardianOwner, guardianPauser));

        console.logString("Guardian Address : ");
        console.logAddress(guardian);

        return guardian;
    }

    // #endregion deploy guardian.

    // #region deploy arrakis timeLock.

    function _deployArrakisTimeLock() internal returns (address) {
        address[] memory proposers = new address[](1);
        proposers[0] = proposer;

        address[] memory executors = new address[](1);
        executors[0] = executor;

        arrakisTimeLock = address(
            new TimelockController(
                minDelay, proposers, executors, timeLockAdmin
            )
        );

        console.logString("Arrakis Time Lock Address (admin) : ");
        console.logAddress(arrakisTimeLock);

        return arrakisTimeLock;
    }

    // #endregion deploy arrakis timeLock.

    // #region deploy arrakis standard manager.

    function _deployArrakisStandardManager(
        address guardian_,
        address arrakisTimeLock_
    ) internal returns (address) {
        address implementation = address(
            new ArrakisStandardManager(
                defaultFeePIPS,
                nativeToken,
                nativeTokenDecimals,
                guardian_
            )
        );

        console.logString(
            "Arrakis Standard Manager Implementation Address : "
        );
        console.logAddress(implementation);

        // #region deploy the proxy admin.

        // NOTE: check if we can remove that for mainnet.
        address proxyAdmin = address(new ProxyAdmin());

        ProxyAdmin(proxyAdmin).transferOwnership(arrakisTimeLock);

        console.logString(
            "Arrakis Standard Manager Proxy Admin Address : "
        );
        console.logAddress(proxyAdmin);

        // #endregion deploy the proxy admin.

        // #region deploy the proxy.

        manager = address(
            new TransparentUpgradeableProxy(
                implementation, proxyAdmin, ""
            )
        );

        console.logString("Arrakis Standard Manager Address : ");
        console.logAddress(manager);

        // #endregion deploy the proxy.

        return manager;
    }

    // #endregion deploy arrakis standard manager.

    // #region deploy public module registry.

    function _deployModuleRegistryPublic(
        address guardian_,
        address arrakisTimeLock_
    ) internal returns (address) {
        publicRegistry = address(
            new ModulePublicRegistry(
                publicModuleRegistryOwner, guardian_, arrakisTimeLock_
            )
        );

        console.logString("Module Public Vault Registry Address : ");
        console.logAddress(publicRegistry);

        return publicRegistry;
    }

    // #endregion deploy public module registry.

    // #region deploy private module registry.

    function _deployModuleRegistryPrivate(
        address guardian_,
        address arrakisTimeLock_
    ) internal returns (address) {
        privateRegistry = address(
            new ModulePrivateRegistry(
                privateModuleRegistryOwner,
                guardian_,
                arrakisTimeLock_
            )
        );

        console.logString("Module Private Vault Registry Address : ");
        console.logAddress(privateRegistry);

        return privateRegistry;
    }

    // #endregion deploy private module registry.

    // #region deploy creation code public vault.

    function _deployCreationCodePublicVault()
        internal
        returns (address)
    {
        creationCodePublicVault =
            address(new CreationCodePublicVault());

        console.logString("Creation Code Public Vault Address : ");
        console.logAddress(creationCodePublicVault);
    }

    // #endregion deploy creation code public vault.

    // #region deploy creation code private vault.

    function _deployCreationCodePrivateVault()
        internal
        returns (address)
    {
        creationCodePrivateVault =
            address(new CreationCodePrivateVault());

        console.logString("Creation Code Private Vault Address : ");
        console.logAddress(creationCodePrivateVault);
    }

    // #endregion deploy creation code private vault.

    // #region deploy factory.

    function _deployFactory(
        address manager_,
        address publicRegistry_,
        address privateRegistry_,
        address createCodePublicVault_,
        address createCodePrivateVault_
    ) internal returns (address) {
        factory = address(
            new ArrakisMetaVaultFactory(
                factoryOwner,
                manager_,
                publicRegistry_,
                privateRegistry_,
                createCodePublicVault_,
                createCodePrivateVault_
            )
        );

        console.logString("Arrakis Meta Vault Factory Address : ");
        console.logAddress(factory);

        return factory;
    }

    // #endregion deploy factory.

    // #region deploy router.

    function _deployRouter(address factory_)
        internal
        returns (address)
    {
        router = address(
            new ArrakisPublicVaultRouter(
                nativeToken, permit2, routerOwner, factory_, weth
            )
        );

        console.logString("Arrakis Public Vault Router Address : ");
        console.logAddress(router);

        return router;
    }

    // #endregion deploy router.

    // #region deploy router executor.

    function _deployRouterExecutor(address router_)
        internal
        returns (address)
    {
        routerExecutor =
            address(new RouterSwapExecutor(router_, nativeToken));

        console.logString("Router Executor Address : ");
        console.logAddress(routerExecutor);

        return routerExecutor;
    }

    // #endregion deploy router executor.

    // #region initialize manager.

    function _initializeManager(address factory_) internal {
        ArrakisStandardManager(payable(manager)).initialize(
            managerOwner, defaultReceiver, factory_
        );

        console.logString("Manager is initialized.");
    }

    // #endregion initialize manager.

    // #region initialize public module.

    function _initializePublicModuleRegistry(address factory_)
        internal
    {
        ModulePublicRegistry(publicRegistry).initialize(factory_);

        console.logString("Public Module Registry is initialized.");
    }

    // #endregion initialize public module.

    // #region initialize private module.

    function _initializePrivateModuleRegistry(address factory_)
        internal
    {
        ModulePrivateRegistry(privateRegistry).initialize(factory_);

        console.logString("Private Module Registry is initialized.");
    }

    // #endregion initialize private module.

    // #region initialize router.

    function _initializeRouter(address routerExecutor_) internal {
        ArrakisPublicVaultRouter(payable(router)).updateSwapExecutor(
            routerExecutor_
        );

        console.logString("Router is initialized.");
    }

    // #endregion initialize router.
}
