// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// #region foundry.

import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";

// #endregion foundry.

import {TestWrapper} from "../utils/TestWrapper.sol";

import {ModulePublicRegistry} from "../../src/ModulePublicRegistry.sol";
import {ArrakisMetaVaultPublic} from "../../src/ArrakisMetaVaultPublic.sol";
import {ArrakisMetaVaultFactory} from "../../src/ArrakisMetaVaultFactory.sol";
import {ArrakisPublicVaultRouter} from "../../src/ArrakisPublicVaultRouter.sol";
import {RouterSwapExecutor} from "../../src/RouterSwapExecutor.sol";
import {ArrakisStandardManager} from "../../src/ArrakisStandardManager.sol";
import {Guardian} from "../../src/Guardian.sol";
import {ValantisModulePublic} from "../../src/modules/ValantisSOTModulePublic.sol";

import {IModulePublicRegistry} from "../../src/interfaces/IModulePublicRegistry.sol";
import {IModuleRegistry} from "../../src/interfaces/IModuleRegistry.sol";
import {IArrakisMetaVaultPublic} from "../../src/interfaces/IArrakisMetaVaultPublic.sol";
import {IArrakisMetaVault} from "../../src/interfaces/IArrakisMetaVault.sol";
import {IArrakisMetaVaultFactory} from "../../src/interfaces/IArrakisMetaVaultFactory.sol";
import {IArrakisPublicVaultRouter} from "../../src/interfaces/IArrakisPublicVaultRouter.sol";
import {IRouterSwapExecutor} from "../../src/interfaces/IRouterSwapExecutor.sol";
import {IArrakisStandardManager} from "../../src/interfaces/IArrakisStandardManager.sol";
import {IValantisSOTModule} from "../../src/interfaces/IValantisSOTModule.sol";

import {NATIVE_COIN, TEN_PERCENT} from "../../src/constants/CArrakis.sol";

import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import {SOTBase} from "../../lib/valantis-sot/test/base/SOTBase.t.sol";
// import {SOTBase} from "@valantis/contracts-test/base/SOTBase.t.sol";

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

    /// @dev the default address that will receive the manager fees.
    address public defaultReceiver;

    address public valantisImplementation;
    address public valantisBeacon;

    address public vault;

    function setUp() public {
        owner = vm.addr(uint256(keccak256(abi.encode("Owner"))));
        pauser = vm.addr(uint256(keccak256(abi.encode("Pauser"))));

        defaultReceiver = vm.addr(uint256(keccak256(abi.encode("Default Receiver"))));

        arrakisTimeLock = vm.addr(uint256(keccak256(abi.encode("Arrakis Time Lock"))));

        /// @dev we will not use it so we mock it.
        address privateModule = vm.addr(uint256(keccak256(abi.encode("Private Module"))));

        // #region create guardian.

        guardian = _deployGuardian(owner, pauser);

        // #endregion create guardian.

        // #region create manager.

        manager = _deployManager(guardian);

        // #endregion create manager.

        // #region create modules.

        moduleRegistry = _deployPublicRegistry(owner, guardian, arrakisTimeLock);

        // #endregion create modules.

        // #region create factory.

        factory = _deployArrakisMetaVaultFactory(owner, manager, moduleRegistry, privateModule);

        // #endregion create factory.

        // #region initialize manager.

        _initializeManager(owner, defaultReceiver, factory);

        // #endregion initialize manager.

        // #region initialize module registry.

        _initializeModuleRegistry(factory);

        // #endregion initialize module registry.

        // #region create valantis module beacon.

        valantisImplementation = _deployValantisImplementation(guardian);
        valantisBeacon = address(new UpgradeableBeacon(valantisImplementation, arrakisTimeLock));

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

        // #region create public vault.

        bytes32 salt = abi.encode("Public vault salt");

        bytes memory moduleCreationPayload = abi.encodeWithSelector(IValantisSOTModule.initialize.selector, );
        bytes memory initManagementPayload = abi.encodeWithSelector(bytes4, arg);

        vault = IArrakisMetaVaultFactory(factory).deployPublicVault(salt_, USDC, WETH, owner, valantisBeacon, , );

        // #endregion create public vault.
    }

    // #region tests.

    function test_deposit() public {

    }

    // #endregion tests.

    // #region internal functions.

    function _deployGuardian(address owner_, address pauser_) internal returns(address guardian) {
        return address(new Guardian(owner_, pauser_));
    }

    function _deployManager(address guardian_) internal returns(address) {
        /// @dev default fee pips is set at 10%

        return address(new ArrakisStandardManager(TEN_PERCENT, NATIVE_COIN, 18, guardian_));
    }

    function _deployPublicRegistry(address owner_, address guardian_, address admin_) internal returns(address) {
        return address(new ModulePublicRegistry(owner, guardian_, admin_));
    }

    function _deployValantisImplementation(address guardian_) internal returns(address) {
        return address(new ValantisModulePublic(guardian_));
    }

    function _deployArrakisMetaVaultFactory(address owner_, address manager_, address modulePublicRegistry_, address modulePrivateRegistry_) internal returns(address) {
        return address(new ArrakisMetaVaultFactory(owner_, manager_, modulePublicRegistry_, modulePrivateRegistry_));
    }

    /// @dev should be called after creation of factory contract.
    function _initializeManager(address owner_, address defaultReceiver_, address factory_) internal {
        IArrakisStandardManager(manager).initialize(owner, defaultReceiver_, factory_);
    }

    /// @dev should be called after creation of factory contract.
    function _initializeModuleRegistry(address factory_) internal {
        IModuleRegistry(moduleRegistry).initialize(factory_);
    }

    // #endregion internal functions.
}
