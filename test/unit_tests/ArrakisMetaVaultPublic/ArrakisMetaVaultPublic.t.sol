// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

import {TestWrapper} from "../../utils/TestWrapper.sol";

import {ArrakisMetaVaultPublic} from
    "../../../src/ArrakisMetaVaultPublic.sol";
import {IArrakisMetaVaultPublic} from
    "../../../src/interfaces/IArrakisMetaVaultPublic.sol";
import {IArrakisMetaVault} from
    "../../../src/interfaces/IArrakisMetaVault.sol";
import {
    MINIMUM_LIQUIDITY,
    BASE
} from "../../../src/constants/CArrakis.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeCast} from
    "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {FullMath} from "@v3-lib-0.8/contracts/FullMath.sol";

import {ERC20} from "@solady/contracts/tokens/ERC20.sol";
import {Ownable} from "@solady/contracts/auth/Ownable.sol";

// #region mock contracts.

import {ManagerMock} from "./mocks/ManagerMock.sol";
import {LpModuleMock} from "./mocks/LpModuleMock.sol";
import {BuggyLpModuleMock} from "./mocks/BuggyLpModuleMock.sol";
import {ModuleRegistryMock} from "./mocks/ModuleRegistryMock.sol";

// #endregion mock contracts.

contract ArrakisMetaVaultPublicTest is TestWrapper {
    // #region constant properties.

    address public constant WETH =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    // #endregion constant properties.

    // #region public properties.

    ArrakisMetaVaultPublic public vault;
    ManagerMock public manager;
    LpModuleMock public module;
    ModuleRegistryMock public moduleRegistry;
    address public owner;

    // #endregion public properties.

    function setUp() public {
        // #region create manager.

        manager = new ManagerMock();

        // #endregion create manager.

        // #region create module.

        module = new LpModuleMock();

        module.setToken0AndToken1(USDC, WETH);
        module.setManager(address(manager));

        // #endregion create module.

        // #region create owner of metaVault.

        owner = vm.addr(uint256(keccak256(abi.encode("Owner"))));

        // #endregion create owner of metaVault.

        // #region create module registry.

        moduleRegistry = new ModuleRegistryMock();

        // #endregion create module registry.

        vault = new ArrakisMetaVaultPublic(
            owner,
            "Arrakis Vault Token",
            "AVT",
            address(moduleRegistry),
            address(manager),
            USDC,
            WETH
        );
    }

    // #region test constructor.

    function testConstructorRegistryAddressZero() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisMetaVault.AddressZero.selector,
                "Module Registry"
            )
        );

        vault = new ArrakisMetaVaultPublic(
            owner,
            "Arrakis Vault Token",
            "AVK",
            address(0),
            address(manager),
            USDC,
            WETH
        );
    }

    function testConstructorManagerAddressZero() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisMetaVault.AddressZero.selector, "Manager"
            )
        );

        vault = new ArrakisMetaVaultPublic(
            owner,
            "Arrakis Vault Token",
            "AVK",
            address(moduleRegistry),
            address(0),
            USDC,
            WETH
        );
    }

    function testConstructorOwnerIsAddressZero() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisMetaVault.AddressZero.selector, "Owner"
            )
        );

        vault = new ArrakisMetaVaultPublic(
            address(0),
            "Arrakis Vault Token",
            "AVK",
            address(moduleRegistry),
            address(manager),
            USDC,
            WETH
        );
    }

    function testConstrutorToken0IsAddressZero() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisMetaVault.AddressZero.selector, "Token 0"
            )
        );

        vault = new ArrakisMetaVaultPublic(
            owner,
            "Arrakis Vault Token",
            "AVK",
            address(moduleRegistry),
            address(manager),
            address(0),
            WETH
        );
    }

    function testConstrutorToken1IsAddressZero() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisMetaVault.AddressZero.selector, "Token 1"
            )
        );

        vault = new ArrakisMetaVaultPublic(
            owner,
            "Arrakis Vault Token",
            "AVK",
            address(moduleRegistry),
            address(manager),
            USDC,
            address(0)
        );
    }

    function testConstrutorToken0GtToken1() public {
        vm.expectRevert(IArrakisMetaVault.Token0GtToken1.selector);

        vault = new ArrakisMetaVaultPublic(
            owner,
            "Arrakis Vault Token",
            "AVK",
            address(moduleRegistry),
            address(manager),
            WETH,
            USDC
        );
    }

    function testConstrutorToken0EqToken1() public {
        vm.expectRevert(IArrakisMetaVault.Token0EqToken1.selector);

        vault = new ArrakisMetaVaultPublic(
            owner,
            "Arrakis Vault Token",
            "AVK",
            address(moduleRegistry),
            address(manager),
            WETH,
            WETH
        );
    }

    function testConstructor() public {
        vault = new ArrakisMetaVaultPublic(
            owner,
            "Arrakis Vault Token",
            "AVK",
            address(moduleRegistry),
            address(manager),
            USDC,
            WETH
        );

        // #region assertions.

        address actualOwner = vault.owner();
        string memory name = vault.name();
        string memory symbol = vault.symbol();
        address actualModuleRegistry = vault.moduleRegistry();
        address actualManager = vault.manager();

        assertEq(actualOwner, owner);
        assertEq(name, "Arrakis Vault Token");
        assertEq(symbol, "AVK");
        assertEq(actualModuleRegistry, address(moduleRegistry));
        assertEq(actualManager, address(manager));

        // #endregion assertions.
    }

    // #endregion test constructor.

    // #region test initialize.

    function testInitializeModuleAddressZero() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisMetaVault.AddressZero.selector, "Module"
            )
        );

        vault.initialize(address(0));
    }

    function testInitialize() public {
        address tModule =
            vm.addr(uint256(keccak256(abi.encode("Test Module"))));

        vault.initialize(tModule);

        address token0 = vault.token0();
        address token1 = vault.token1();
        address actualModule = address(vault.module());

        address[] memory whitelistedModules =
            vault.whitelistedModules();

        assertEq(token0, USDC);
        assertEq(token1, WETH);
        assert(whitelistedModules.length == 1);
        assertEq(whitelistedModules[0], tModule);
        assertEq(actualModule, tModule);
    }

    // #endregion test initialize.

    // #region test setModule functions.

    function testSetModuleOnlyManager() public {
        // #region initialize.

        address tModule =
            vm.addr(uint256(keccak256(abi.encode("Test Module"))));

        vault.initialize(tModule);

        address actualModule = address(vault.module());

        address[] memory whitelistedModules =
            vault.whitelistedModules();

        assert(whitelistedModules.length == 1);
        assertEq(whitelistedModules[0], tModule);
        assertEq(actualModule, tModule);

        // #endregion initialize.

        address[] memory beacons = new address[](1);
        bytes[] memory datas = new bytes[](1);

        address beacon =
            vm.addr(uint256(keccak256(abi.encode("Beacon"))));

        beacons[0] = beacon;

        // #region whitelist module.

        vm.prank(owner);
        vault.whitelistModules(beacons, datas);

        address newModule = (vault.whitelistedModules())[1];

        // #endregion whitelist module.

        address caller = vm.addr(2);

        vm.prank(caller);

        bytes[] memory payloads = new bytes[](0);

        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisMetaVault.OnlyManager.selector,
                caller,
                address(manager)
            )
        );

        vault.setModule(newModule, payloads);
    }

    function testSetModuleSameModule() public {
        // #region initialize.

        address tModule =
            vm.addr(uint256(keccak256(abi.encode("Test Module"))));

        vault.initialize(tModule);

        address actualModule = address(vault.module());

        address[] memory whitelistedModules =
            vault.whitelistedModules();

        assert(whitelistedModules.length == 1);
        assertEq(whitelistedModules[0], tModule);
        assertEq(actualModule, tModule);

        // #endregion initialize.

        bytes[] memory payloads = new bytes[](0);

        vm.expectRevert(IArrakisMetaVault.SameModule.selector);

        vm.prank(address(manager));
        vault.setModule(actualModule, payloads);
    }

    function testSetModuleNotWhitelistedModule() public {
        // #region initialize.

        address tModule =
            vm.addr(uint256(keccak256(abi.encode("Test Module"))));

        vault.initialize(tModule);

        address actualModule = address(vault.module());

        address[] memory whitelistedModules =
            vault.whitelistedModules();

        assert(whitelistedModules.length == 1);
        assertEq(whitelistedModules[0], tModule);
        assertEq(actualModule, tModule);

        // #endregion initialize.

        address newModule =
            vm.addr(uint256(keccak256(abi.encode("New Module"))));

        bytes[] memory payloads = new bytes[](0);

        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisMetaVault.NotWhitelistedModule.selector,
                newModule
            )
        );

        vm.prank(address(manager));
        vault.setModule(newModule, payloads);
    }

    function testSetModuleBuggyModule() public {
        // #region initialize.

        BuggyLpModuleMock buggyModule = new BuggyLpModuleMock();

        vault.initialize(address(buggyModule));

        address actualModule = address(vault.module());

        address[] memory whitelistedModules =
            vault.whitelistedModules();

        assert(whitelistedModules.length == 1);
        assertEq(whitelistedModules[0], address(buggyModule));
        assertEq(actualModule, address(buggyModule));

        // #endregion initialize.

        address[] memory beacons = new address[](1);
        bytes[] memory datas = new bytes[](1);

        address beacon =
            vm.addr(uint256(keccak256(abi.encode("Beacon"))));

        beacons[0] = beacon;

        // #region whitelist module.

        vm.prank(owner);
        vault.whitelistModules(beacons, datas);

        address newModule = (vault.whitelistedModules())[1];

        // #endregion whitelist module.

        // #region mock current module.

        buggyModule.setToken0AndToken1(USDC, WETH);
        buggyModule.setManager(address(manager));
        deal(USDC, address(buggyModule), 4000e6);
        deal(WETH, address(buggyModule), 2e18);
        buggyModule.setManagerBalance0AndBalance1(2000e6, 1e18);

        // #endregion mock current module.

        bytes[] memory payloads = new bytes[](0);

        vm.prank(address(manager));
        vault.setModule(newModule, payloads);
    }

    function testSetModuleBuggyNewModule() public {
        // #region initialize.

        vault.initialize(address(module));

        address actualModule = address(vault.module());

        address[] memory whitelistedModules =
            vault.whitelistedModules();

        assert(whitelistedModules.length == 1);
        assertEq(whitelistedModules[0], address(module));
        assertEq(actualModule, address(module));

        // #endregion initialize.

        address[] memory beacons = new address[](1);
        bytes[] memory datas = new bytes[](1);

        datas[0] = abi.encode(1);

        address beacon =
            vm.addr(uint256(keccak256(abi.encode("Beacon"))));

        beacons[0] = beacon;

        // #region whitelist module.

        vm.prank(owner);
        vault.whitelistModules(beacons, datas);

        address newModule = (vault.whitelistedModules())[1];

        // #endregion whitelist module.

        bytes[] memory payloads = new bytes[](1);

        payloads[0] = abi.encodeWithSelector(
            LpModuleMock.smallCall.selector, 10
        );

        vm.prank(address(manager));
        vm.expectRevert(IArrakisMetaVault.CallFailed.selector);
        vault.setModule(newModule, payloads);
    }

    function testSetModule() public {
        // #region initialize.

        vault.initialize(address(module));

        address actualModule = address(vault.module());

        address[] memory whitelistedModules =
            vault.whitelistedModules();

        assert(whitelistedModules.length == 1);
        assertEq(whitelistedModules[0], address(module));
        assertEq(actualModule, address(module));

        // #endregion initialize.

        address[] memory beacons = new address[](1);
        bytes[] memory datas = new bytes[](1);

        address beacon =
            vm.addr(uint256(keccak256(abi.encode("Beacon"))));

        beacons[0] = beacon;

        // #region whitelist module.

        vm.prank(owner);
        vault.whitelistModules(beacons, datas);

        address newModule = (vault.whitelistedModules())[1];

        // #endregion whitelist module.

        bytes[] memory payloads = new bytes[](0);

        vm.prank(address(manager));
        vault.setModule(newModule, payloads);
    }

    function testSetModuleNewModuleWithPayload() public {
        // #region initialize.

        vault.initialize(address(module));

        address actualModule = address(vault.module());

        address[] memory whitelistedModules =
            vault.whitelistedModules();

        assert(whitelistedModules.length == 1);
        assertEq(whitelistedModules[0], address(module));
        assertEq(actualModule, address(module));

        // #endregion initialize.

        address[] memory beacons = new address[](1);
        bytes[] memory datas = new bytes[](1);

        address beacon =
            vm.addr(uint256(keccak256(abi.encode("Beacon"))));

        beacons[0] = beacon;

        // #region whitelist module.

        vm.prank(owner);
        vault.whitelistModules(beacons, datas);

        address newModule = (vault.whitelistedModules())[1];

        // #endregion whitelist module.

        bytes[] memory payloads = new bytes[](1);

        payloads[0] = abi.encodeWithSelector(
            LpModuleMock.smallCall.selector, 10
        );

        vm.prank(address(manager));
        vault.setModule(newModule, payloads);

        assertEq(LpModuleMock(newModule).someValue(), 10);
    }

    // #endregion test setModule functions.

    // #region test whitelist modules.

    function testWhitelistModulesOnlyOwner() public {
        address newBeacon =
            vm.addr(uint256(keccak256(abi.encode("New Beacon"))));

        address[] memory beacons = new address[](1);

        beacons[0] = newBeacon;

        bytes[] memory payloads = new bytes[](1);

        vm.expectRevert(IArrakisMetaVault.OnlyOwner.selector);

        vault.whitelistModules(beacons, payloads);
    }

    function testWhitelistModulesNotSameLengthArray() public {
        // #region initialize.

        vault.initialize(address(module));

        address actualModule = address(vault.module());

        address[] memory whitelistedModules =
            vault.whitelistedModules();

        assert(whitelistedModules.length == 1);
        assertEq(whitelistedModules[0], address(module));
        assertEq(actualModule, address(module));

        // #endregion initialize.

        address[] memory beacons = new address[](1);
        bytes[] memory datas = new bytes[](2);

        address beacon =
            vm.addr(uint256(keccak256(abi.encode("Beacon"))));

        beacons[0] = beacon;

        // #region whitelist module.

        vm.prank(owner);
        vm.expectRevert(IArrakisMetaVault.ArrayNotSameLength.selector);
        vault.whitelistModules(beacons, datas);

        // #endregion whitelist module.
    }

    function testWhitelistModules() public {
        // #region initialize.

        vault.initialize(address(module));

        address actualModule = address(vault.module());

        address[] memory whitelistedModules =
            vault.whitelistedModules();

        assert(whitelistedModules.length == 1);
        assertEq(whitelistedModules[0], address(module));
        assertEq(actualModule, address(module));

        // #endregion initialize.

        address[] memory beacons = new address[](1);
        bytes[] memory datas = new bytes[](1);

        address beacon =
            vm.addr(uint256(keccak256(abi.encode("Beacon"))));

        beacons[0] = beacon;

        // #region whitelist module.

        vm.prank(owner);
        vault.whitelistModules(beacons, datas);

        address[] memory modules = vault.whitelistedModules();

        assert(modules.length == 2);
        assertEq(modules[0], address(module));
        assertNotEq(modules[1], address(0));
        assertNotEq(modules[1], address(module));

        // #endregion whitelist module.
    }

    // #endregion test whitelist modules.

    // #region test blacklist modules.

    function testBlacklistModulesOnlyOwner() public {
        // #region initialize.

        vault.initialize(address(module));

        address actualModule = address(vault.module());

        address[] memory whitelistedModules =
            vault.whitelistedModules();

        assert(whitelistedModules.length == 1);
        assertEq(whitelistedModules[0], address(module));
        assertEq(actualModule, address(module));

        // #endregion initialize.

        address[] memory beacons = new address[](1);
        bytes[] memory datas = new bytes[](1);

        address beacon =
            vm.addr(uint256(keccak256(abi.encode("Beacon"))));

        beacons[0] = beacon;

        // #region whitelist module.

        vm.prank(owner);
        vault.whitelistModules(beacons, datas);

        address[] memory modules = vault.whitelistedModules();

        assert(modules.length == 2);
        assertEq(modules[0], address(module));
        assertNotEq(modules[1], address(0));
        assertNotEq(modules[1], address(module));

        // #endregion whitelist module.

        // #region blacklist module.

        address[] memory modulesToRemove = new address[](1);
        modulesToRemove[0] = modules[1];

        vm.expectRevert(IArrakisMetaVault.OnlyOwner.selector);
        vault.blacklistModules(modulesToRemove);

        // #endregion blacklist module.
    }

    function testBlacklistModulesNotWhitelisted() public {
        address newModule =
            vm.addr(uint256(keccak256(abi.encode("New Module"))));

        address[] memory modulesToRemove = new address[](1);

        modulesToRemove[0] = newModule;

        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisMetaVault.NotWhitelistedModule.selector,
                newModule
            )
        );

        vm.prank(owner);

        vault.blacklistModules(modulesToRemove);
    }

    function testBlacklistModulesActiveModule() public {
        // #region initialize.

        vault.initialize(address(module));

        address actualModule = address(vault.module());

        address[] memory whitelistedModules =
            vault.whitelistedModules();

        assert(whitelistedModules.length == 1);
        assertEq(whitelistedModules[0], address(module));
        assertEq(actualModule, address(module));

        // #endregion initialize.

        address[] memory modules = new address[](1);

        modules[0] = address(module);

        vm.expectRevert(IArrakisMetaVault.ActiveModule.selector);

        vm.prank(owner);

        vault.blacklistModules(modules);
    }

    function testBlacklistModules() public {
        // #region initialize.

        vault.initialize(address(module));

        address actualModule = address(vault.module());

        address[] memory whitelistedModules =
            vault.whitelistedModules();

        assert(whitelistedModules.length == 1);
        assertEq(whitelistedModules[0], address(module));
        assertEq(actualModule, address(module));

        // #endregion initialize.

        address[] memory beacons = new address[](1);
        bytes[] memory datas = new bytes[](1);

        address beacon =
            vm.addr(uint256(keccak256(abi.encode("Beacon"))));

        beacons[0] = beacon;

        // #region whitelist module.

        vm.prank(owner);
        vault.whitelistModules(beacons, datas);

        address[] memory modules = vault.whitelistedModules();

        assert(modules.length == 2);
        assertEq(modules[0], address(module));
        assertNotEq(modules[1], address(0));
        assertNotEq(modules[1], address(module));

        // #endregion whitelist module.

        address[] memory modulesToRemove = new address[](1);
        modulesToRemove[0] = modules[1];

        vm.prank(owner);
        vault.blacklistModules(modulesToRemove);

        modules = vault.whitelistedModules();
        assert(modules.length == 1);
        assertEq(modules[0], address(module));
    }

    // #endregion test blacklist modules.

    // #region test whitelisted modules.

    function testWhitelistedModules() public {
        // #region initialize.

        vault.initialize(address(module));

        address actualModule = address(vault.module());

        address[] memory whitelistedModules =
            vault.whitelistedModules();

        assert(whitelistedModules.length == 1);
        assertEq(whitelistedModules[0], address(module));
        assertEq(actualModule, address(module));

        // #endregion initialize.

        address[] memory beacons = new address[](1);
        bytes[] memory datas = new bytes[](1);

        address beacon =
            vm.addr(uint256(keccak256(abi.encode("Beacon"))));

        beacons[0] = beacon;

        // #region whitelist module.

        vm.prank(owner);
        vault.whitelistModules(beacons, datas);

        whitelistedModules = vault.whitelistedModules();

        assert(whitelistedModules.length == 2);
        assertEq(whitelistedModules[0], address(module));
        assertNotEq(whitelistedModules[1], address(0));
        assertNotEq(whitelistedModules[1], address(module));

        // #endregion whitelist module.
    }

    // #endregion test whitelisted modules.

    // #region test getInits.

    function testGetInits() public {
        // #region initialize.

        vault.initialize(address(module));

        address actualModule = address(vault.module());

        address[] memory whitelistedModules =
            vault.whitelistedModules();

        assert(whitelistedModules.length == 1);
        assertEq(whitelistedModules[0], address(module));
        assertEq(actualModule, address(module));

        // #endregion initialize.

        // #region mock inits.

        uint256 i0 = 2000e6;
        uint256 i1 = 1e18;

        module.setInits(i0, i1);

        // #endregion mock inits.

        (uint256 init0, uint256 init1) = vault.getInits();

        assertEq(init0, i0);
        assertEq(init1, i1);
    }

    // #endregion test getInits.

    // #region test totalUnderlying.

    function testTotalUnderlying() public {
        // #region initialize.

        vault.initialize(address(module));

        address actualModule = address(vault.module());

        address[] memory whitelistedModules =
            vault.whitelistedModules();

        assert(whitelistedModules.length == 1);
        assertEq(whitelistedModules[0], address(module));
        assertEq(actualModule, address(module));

        // #endregion initialize.
        uint256 managerBalance0 = 2000e6;
        uint256 managerBalance1 = 1e18;

        module.setToken0AndToken1(USDC, WETH);
        module.setManagerBalance0AndBalance1(
            managerBalance0, managerBalance1
        );

        deal(USDC, address(module), managerBalance0 * 101);
        deal(WETH, address(module), managerBalance1 * 101);

        (uint256 amount0, uint256 amount1) = vault.totalUnderlying();

        assertEq(managerBalance0 * 100, amount0);
        assertEq(managerBalance1 * 100, amount1);
    }

    // #endregion test totalUnderlying.

    // #region test totalUnderlyingAtPrice.

    function testTotalUnderlyingAtPrice() public {
        // #region initialize.

        vault.initialize(address(module));

        address actualModule = address(vault.module());

        address[] memory whitelistedModules =
            vault.whitelistedModules();

        assert(whitelistedModules.length == 1);
        assertEq(whitelistedModules[0], address(module));
        assertEq(actualModule, address(module));

        // #endregion initialize.
        uint256 managerBalance0 = 2000e6;
        uint256 managerBalance1 = 1e18;

        module.setToken0AndToken1(USDC, WETH);
        module.setManagerBalance0AndBalance1(
            managerBalance0, managerBalance1
        );

        deal(USDC, address(module), managerBalance0 * 101);
        deal(WETH, address(module), managerBalance1 * 101);

        (uint256 amount0, uint256 amount1) =
            vault.totalUnderlyingAtPrice(3000e6);

        assertEq((managerBalance0 * 100) / 2, amount0);
        assertEq((managerBalance1 * 100) * 2, amount1);
    }

    // #endregion test totalUnderlyingAtPrice.

    // #region test mint.

    function testMintShareZero() public {
        address user = vm.addr(uint256(keccak256(abi.encode("User"))));
        // #region initialize.

        vault.initialize(address(module));

        address actualModule = address(vault.module());

        address[] memory whitelistedModules =
            vault.whitelistedModules();

        assert(whitelistedModules.length == 1);
        assertEq(whitelistedModules[0], address(module));
        assertEq(actualModule, address(module));

        // #endregion initialize.

        // #region mock inits.

        uint256 i0 = 2000e6;
        uint256 i1 = 1e18;

        module.setInits(i0, i1);

        // #endregion mock inits.

        uint256 shares = 0;

        vm.startPrank(user);
        vm.expectRevert(IArrakisMetaVaultPublic.MintZero.selector);

        vault.mint(shares, user);

        vm.stopPrank();
    }

    function testMintReceiverAddressZero() public {
        address user = vm.addr(uint256(keccak256(abi.encode("User"))));
        address receiver = address(0);
        // #region initialize.

        vault.initialize(address(module));

        address actualModule = address(vault.module());

        address[] memory whitelistedModules =
            vault.whitelistedModules();

        assert(whitelistedModules.length == 1);
        assertEq(whitelistedModules[0], address(module));
        assertEq(actualModule, address(module));

        // #endregion initialize.

        // #region mock inits.

        uint256 i0 = 2000e6;
        uint256 i1 = 1e18;

        module.setInits(i0, i1);

        // #endregion mock inits.
        uint256 shares = 1 ether / 2;

        // #region get total underlying.

        (uint256 total0, uint256 total1) = vault.getInits();

        // #endregion get total underlying.

        uint256 expectedAmount0 =
            FullMath.mulDiv(total0, shares, 1 ether);
        uint256 expectedAmount1 =
            FullMath.mulDiv(total1, shares, 1 ether);

        deal(USDC, user, expectedAmount0);
        deal(WETH, user, expectedAmount1);

        vm.startPrank(user);

        IERC20(USDC).approve(address(module), expectedAmount0);
        IERC20(WETH).approve(address(module), expectedAmount1);

        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisMetaVault.AddressZero.selector, "Receiver"
            )
        );

        vault.mint(shares, receiver);

        vm.stopPrank();
    }

    function testMint() public {
        address user = vm.addr(uint256(keccak256(abi.encode("User"))));
        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));
        // #region initialize.

        vault.initialize(address(module));

        address actualModule = address(vault.module());

        address[] memory whitelistedModules =
            vault.whitelistedModules();

        assert(whitelistedModules.length == 1);
        assertEq(whitelistedModules[0], address(module));
        assertEq(actualModule, address(module));

        // #endregion initialize.

        // #region mock inits.

        uint256 i0 = 2000e6;
        uint256 i1 = 1e18;

        module.setInits(i0, i1);

        // #endregion mock inits.

        // #region set token0 and token1

        module.setToken0AndToken1(USDC, WETH);

        // #endregion set token0 and token1

        uint256 shares = 1 ether / 2;

        // #region get total underlying.

        (uint256 total0, uint256 total1) = vault.getInits();

        // #endregion get total underlying.

        uint256 expectedAmount0 =
            FullMath.mulDiv(total0, shares, 1 ether);
        uint256 expectedAmount1 =
            FullMath.mulDiv(total1, shares, 1 ether);

        deal(USDC, user, expectedAmount0);
        deal(WETH, user, expectedAmount1);

        vm.startPrank(user);

        IERC20(USDC).approve(address(module), expectedAmount0);
        IERC20(WETH).approve(address(module), expectedAmount1);

        vault.mint(shares, receiver);

        vm.stopPrank();
    }

    // #endregion test mint.

    // #region test burn.

    function testBurnWithNoToken() public {
        // #region mint.

        address user = vm.addr(uint256(keccak256(abi.encode("User"))));
        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));
        // #region initialize.

        vault.initialize(address(module));

        address actualModule = address(vault.module());

        address[] memory whitelistedModules =
            vault.whitelistedModules();

        assert(whitelistedModules.length == 1);
        assertEq(whitelistedModules[0], address(module));
        assertEq(actualModule, address(module));

        // #endregion initialize.

        // #region mock inits.

        uint256 i0 = 2000e6;
        uint256 i1 = 1e18;

        module.setInits(i0, i1);

        // #endregion mock inits.

        // #region set token0 and token1

        module.setToken0AndToken1(USDC, WETH);

        // #endregion set token0 and token1

        uint256 shares = 1 ether / 2;

        // #region get total underlying.

        (uint256 total0, uint256 total1) = vault.getInits();

        // #endregion get total underlying.

        uint256 expectedAmount0 =
            FullMath.mulDiv(total0, shares, 1 ether);
        uint256 expectedAmount1 =
            FullMath.mulDiv(total1, shares, 1 ether);

        deal(USDC, user, expectedAmount0);
        deal(WETH, user, expectedAmount1);

        vm.startPrank(user);

        IERC20(USDC).approve(address(module), expectedAmount0);
        IERC20(WETH).approve(address(module), expectedAmount1);

        vault.mint(shares, receiver);

        // #endregion mint.
        vm.stopPrank();

        address withdrawer =
            vm.addr(uint256(keccak256(abi.encode("Withdrawer"))));
        address caller =
            vm.addr(uint256(keccak256(abi.encode("Caller"))));

        vm.prank(caller);
        vm.expectRevert(ERC20.InsufficientBalance.selector);
        vault.burn(shares, withdrawer);
    }

    function testBurnMoreThanTotalSupply() public {
        // #region mint.

        address user = vm.addr(uint256(keccak256(abi.encode("User"))));
        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));
        // #region initialize.

        vault.initialize(address(module));

        address actualModule = address(vault.module());

        address[] memory whitelistedModules =
            vault.whitelistedModules();

        assert(whitelistedModules.length == 1);
        assertEq(whitelistedModules[0], address(module));
        assertEq(actualModule, address(module));

        // #endregion initialize.

        // #region mock inits.

        uint256 i0 = 2000e6;
        uint256 i1 = 1e18;

        module.setInits(i0, i1);

        // #endregion mock inits.

        // #region set token0 and token1

        module.setToken0AndToken1(USDC, WETH);

        // #endregion set token0 and token1

        uint256 shares = 1 ether / 2;

        // #region get total underlying.

        (uint256 total0, uint256 total1) = vault.getInits();

        // #endregion get total underlying.

        uint256 expectedAmount0 =
            FullMath.mulDiv(total0, shares, 1 ether);
        uint256 expectedAmount1 =
            FullMath.mulDiv(total1, shares, 1 ether);

        deal(USDC, user, expectedAmount0);
        deal(WETH, user, expectedAmount1);

        vm.startPrank(user);

        IERC20(USDC).approve(address(module), expectedAmount0);
        IERC20(WETH).approve(address(module), expectedAmount1);

        vault.mint(shares, receiver);

        vm.stopPrank();

        // #endregion mint.

        address withdrawer =
            vm.addr(uint256(keccak256(abi.encode("Withdrawer"))));

        vm.expectRevert(IArrakisMetaVaultPublic.BurnOverflow.selector);
        vm.prank(receiver);
        vault.burn(shares + 1, withdrawer);
    }

    function testBurnZero() public {
        // #region mint.

        address user = vm.addr(uint256(keccak256(abi.encode("User"))));
        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));
        // #region initialize.

        vault.initialize(address(module));

        address actualModule = address(vault.module());

        address[] memory whitelistedModules =
            vault.whitelistedModules();

        assert(whitelistedModules.length == 1);
        assertEq(whitelistedModules[0], address(module));
        assertEq(actualModule, address(module));

        // #endregion initialize.

        // #region mock inits.

        uint256 i0 = 2000e6;
        uint256 i1 = 1e18;

        module.setInits(i0, i1);

        // #endregion mock inits.

        // #region set token0 and token1

        module.setToken0AndToken1(USDC, WETH);

        // #endregion set token0 and token1

        uint256 shares = 1 ether / 2;

        // #region get total underlying.

        (uint256 total0, uint256 total1) = vault.getInits();

        // #endregion get total underlying.

        uint256 expectedAmount0 =
            FullMath.mulDiv(total0, shares, 1 ether);
        uint256 expectedAmount1 =
            FullMath.mulDiv(total1, shares, 1 ether);

        deal(USDC, user, expectedAmount0);
        deal(WETH, user, expectedAmount1);

        vm.startPrank(user);

        IERC20(USDC).approve(address(module), expectedAmount0);
        IERC20(WETH).approve(address(module), expectedAmount1);

        vault.mint(shares, receiver);

        vm.stopPrank();

        // #endregion mint.

        address withdrawer =
            vm.addr(uint256(keccak256(abi.encode("Withdrawer"))));

        vm.prank(receiver);
        vm.expectRevert(IArrakisMetaVaultPublic.BurnZero.selector);

        vault.burn(0, withdrawer);
    }

    function testBurnWithdrawerAddressZero() public {
        // #region mint.

        address user = vm.addr(uint256(keccak256(abi.encode("User"))));
        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));
        // #region initialize.

        vault.initialize(address(module));

        address actualModule = address(vault.module());

        address[] memory whitelistedModules =
            vault.whitelistedModules();

        assert(whitelistedModules.length == 1);
        assertEq(whitelistedModules[0], address(module));
        assertEq(actualModule, address(module));

        // #endregion initialize.

        // #region mock inits.

        uint256 i0 = 2000e6;
        uint256 i1 = 1e18;

        module.setInits(i0, i1);

        // #endregion mock inits.

        // #region set token0 and token1

        module.setToken0AndToken1(USDC, WETH);

        // #endregion set token0 and token1

        uint256 shares = 1 ether / 2;

        // #region get total underlying.

        (uint256 total0, uint256 total1) = vault.getInits();

        // #endregion get total underlying.

        uint256 expectedAmount0 =
            FullMath.mulDiv(total0, shares, 1 ether);
        uint256 expectedAmount1 =
            FullMath.mulDiv(total1, shares, 1 ether);

        deal(USDC, user, expectedAmount0);
        deal(WETH, user, expectedAmount1);

        vm.startPrank(user);

        IERC20(USDC).approve(address(module), expectedAmount0);
        IERC20(WETH).approve(address(module), expectedAmount1);

        vault.mint(shares, receiver);

        vm.stopPrank();

        // #endregion mint.

        address withdrawer = address(0);

        vm.prank(receiver);

        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisMetaVault.AddressZero.selector, "Receiver"
            )
        );

        vault.burn(shares, withdrawer);
    }

    function testBurn() public {
        // #region mint.

        address user = vm.addr(uint256(keccak256(abi.encode("User"))));
        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));
        // #region initialize.

        vault.initialize(address(module));

        address actualModule = address(vault.module());

        address[] memory whitelistedModules =
            vault.whitelistedModules();

        assert(whitelistedModules.length == 1);
        assertEq(whitelistedModules[0], address(module));
        assertEq(actualModule, address(module));

        // #endregion initialize.

        // #region mock inits.

        uint256 i0 = 2000e6;
        uint256 i1 = 1e18;

        module.setInits(i0, i1);

        // #endregion mock inits.

        // #region set token0 and token1

        module.setToken0AndToken1(USDC, WETH);

        // #endregion set token0 and token1

        uint256 shares = 1 ether / 2;

        // #region get total underlying.

        (uint256 total0, uint256 total1) = vault.getInits();

        // #endregion get total underlying.

        uint256 expectedAmount0 =
            FullMath.mulDiv(total0, shares, 1 ether);
        uint256 expectedAmount1 =
            FullMath.mulDiv(total1, shares, 1 ether);

        deal(USDC, user, expectedAmount0);
        deal(WETH, user, expectedAmount1);

        vm.startPrank(user);

        IERC20(USDC).approve(address(module), expectedAmount0);
        IERC20(WETH).approve(address(module), expectedAmount1);

        vault.mint(shares, receiver);

        vm.stopPrank();

        // #endregion mint.

        address withdrawer =
            vm.addr(uint256(keccak256(abi.encode("Withdrawer"))));

        vm.prank(receiver);

        vault.burn(shares - MINIMUM_LIQUIDITY, withdrawer);

        assertEq(IERC20(address(vault)).balanceOf(receiver), 0);

        assertNotEq(IERC20(USDC).balanceOf(withdrawer), 0);
        assertNotEq(IERC20(WETH).balanceOf(withdrawer), 0);
    }

    // #endregion test burn.

    // #region test transferOwnership.

    function testTransferOwnership() public {
        address newOwner =
            vm.addr(uint256(keccak256(abi.encode("New Owner"))));
        vm.expectRevert(IArrakisMetaVault.NotImplemented.selector);

        vault.transferOwnership(newOwner);
    }

    // #endregion test transferOwnership.

    // #region test renounceOwnership.

    function testRenounceOwnership() public {
        vm.expectRevert(IArrakisMetaVault.NotImplemented.selector);

        vault.renounceOwnership();
    }

    // #endregion test renounceOwnership.

    // #region test completeOwnershipHandover.

    function testCompleteOwnershipHandover() public {
        address newOwner =
            vm.addr(uint256(keccak256(abi.encode("New Owner"))));
        vm.expectRevert(IArrakisMetaVault.NotImplemented.selector);

        vault.completeOwnershipHandover(newOwner);
    }

    // #endregion test renounceOwnership.

    // #region test name.

    function testName() public {
        string memory name = vault.name();
        assertEq(name, "Arrakis Vault Token");
    }

    // #endregion test name.

    // #region test symbol.

    function testSymbol() public {
        string memory symbol = vault.symbol();
        assertEq(symbol, "AVT");
    }

    // #endregion test symbol.
}
