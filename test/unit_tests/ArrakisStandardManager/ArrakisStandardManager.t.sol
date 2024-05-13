// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

import {TestWrapper} from "../../utils/TestWrapper.sol";

import {ArrakisStandardManager} from
    "../../../src/ArrakisStandardManager.sol";
import {IArrakisStandardManager} from
    "../../../src/interfaces/IArrakisStandardManager.sol";
import {ArrakisMetaVaultFactory} from
    "../../../src/ArrakisMetaVaultFactory.sol";
import {IArrakisMetaVault} from
    "../../../src/interfaces/IArrakisMetaVault.sol";
import {
    PIPS,
    TEN_PERCENT,
    NATIVE_COIN,
    WEEK
} from "../../../src/constants/CArrakis.sol";
import {
    SetupParams,
    FeeIncrease,
    VaultInfo
} from "../../../src/structs/SManager.sol";
import {Guardian} from "../../../src/Guardian.sol";
import {IGuardian} from "../../../src/interfaces/IGuardian.sol";
import {IOracleWrapper} from
    "../../../src/interfaces/IOracleWrapper.sol";

// #region solady.

import {Ownable} from "@solady/contracts/auth/Ownable.sol";

// #endregion solady.

// #region openzeppelin.

import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {SafeCast} from
    "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {UpgradeableBeacon} from
    "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {ERC1967Proxy} from
    "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// #endregion openzeppelin.

// #region mock contracts.

import {GuardianMock} from "./mocks/GuardianMock.sol";
import {ArrakisMetaVaultFactoryMock} from
    "./mocks/ArrakisMetaVaultFactoryMock.sol";
import {ArrakisMetaVaultMock} from "./mocks/ArrakisMetaVaultMock.sol";
import {LpModuleMock} from "./mocks/LpModuleMock.sol";
import {OracleMock} from "./mocks/OracleMock.sol";

// #endregion mock contracts.

contract ArrakisStandardManagerTest is TestWrapper {
    // #region constant properties.

    address public constant WETH =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    /// @dev native token ether in our case.
    /// follow uniswap v4 standard
    /// https://github.com/Uniswap/v4-core/blob/8109ec3c2f9db321ba48fff44ed429e6c1bd3eb3/src/types/Currency.sol#L37
    uint8 public constant nativeTokenDecimals = 18;
    uint256 public constant defaultFeePIPS = TEN_PERCENT;

    // #endregion constant properties.

    // #region public properties.

    address public guardian;
    address public owner;
    address public defaultReceiver;
    address public factory;

    ArrakisStandardManager public manager;

    // #region public properties.

    // #region events.

    event LogStrategyAnnouncement(address vault, string strategy);

    // #endregion events.

    function setUp() public {
        // #region create guardian.

        GuardianMock guardianMock = new GuardianMock();

        address pauser =
            vm.addr(uint256(keccak256(abi.encode("Pauser"))));

        guardianMock.setPauser(pauser);

        assertEq(guardianMock.pauser(), pauser);

        guardian = address(guardianMock);

        // #endregion create guardian.

        // #region create standard manager.

        address implementation = address(
            new ArrakisStandardManager(
                defaultFeePIPS,
                NATIVE_COIN,
                nativeTokenDecimals,
                address(guardian)
            )
        );

        manager = ArrakisStandardManager(
            payable(address(new ERC1967Proxy(implementation, "")))
        );

        // #endregion create standard manager.

        // #region create mock factory.

        ArrakisMetaVaultFactoryMock factoryMock =
            new ArrakisMetaVaultFactoryMock();
        factoryMock.setManager(address(manager));

        factory = address(factoryMock);

        // #endregion create mock factory.

        // #region initialize standard manager.

        owner = vm.addr(uint256(keccak256(abi.encode("Owner"))));
        defaultReceiver =
            vm.addr(uint256(keccak256(abi.encode("DefaultReceiver"))));

        manager.initialize(owner, defaultReceiver, factory);

        // #endregion initialize standard manager.
    }

    // #region test constructor.

    function testConstructorNativeTokenAddressZero() public {
        vm.expectRevert(IArrakisStandardManager.AddressZero.selector);

        manager = new ArrakisStandardManager(
            defaultFeePIPS, address(0), nativeTokenDecimals, guardian
        );
    }

    function testConstructorNativeTokenDecimalsZero() public {
        vm.expectRevert(
            IArrakisStandardManager.NativeTokenDecimalsZero.selector
        );

        manager = new ArrakisStandardManager(
            defaultFeePIPS, NATIVE_COIN, 0, guardian
        );
    }

    function testConstructorGuardianAddressZero() public {
        vm.expectRevert(IArrakisStandardManager.AddressZero.selector);

        manager = new ArrakisStandardManager(
            defaultFeePIPS,
            NATIVE_COIN,
            nativeTokenDecimals,
            address(0)
        );
    }

    function testConstructor() public {
        manager = new ArrakisStandardManager(
            defaultFeePIPS, NATIVE_COIN, nativeTokenDecimals, guardian
        );

        assertEq(
            defaultFeePIPS,
            IArrakisStandardManager(manager).defaultFeePIPS()
        );
        assertEq(
            NATIVE_COIN,
            IArrakisStandardManager(manager).nativeToken()
        );
        assertEq(
            nativeTokenDecimals,
            IArrakisStandardManager(manager).nativeTokenDecimals()
        );
        assertEq(
            IGuardian(guardian).pauser(),
            IArrakisStandardManager(manager).guardian()
        );
    }

    // #endregion test constructor.

    // #region test initialize.

    function testInitializeOwnerAddressZero() public {
        // #region create a new manager.

        address implementation = address(
            new ArrakisStandardManager(
                defaultFeePIPS,
                NATIVE_COIN,
                nativeTokenDecimals,
                address(guardian)
            )
        );

        manager = ArrakisStandardManager(
            payable(address(new ERC1967Proxy(implementation, "")))
        );

        // #endregion create a new manager.

        vm.expectRevert(IArrakisStandardManager.AddressZero.selector);

        manager.initialize(address(0), defaultReceiver, factory);
    }

    function testInitializeDefaultReceiverAddressZero() public {
        // #region create a new manager.

        address implementation = address(
            new ArrakisStandardManager(
                defaultFeePIPS,
                NATIVE_COIN,
                nativeTokenDecimals,
                address(guardian)
            )
        );

        manager = ArrakisStandardManager(
            payable(address(new ERC1967Proxy(implementation, "")))
        );

        // #endregion create a new manager.

        vm.expectRevert(IArrakisStandardManager.AddressZero.selector);

        manager.initialize(owner, address(0), factory);
    }

    function testInitializeFactoryAddressZero() public {
        // #region create a new manager.

        address implementation = address(
            new ArrakisStandardManager(
                defaultFeePIPS,
                NATIVE_COIN,
                nativeTokenDecimals,
                address(guardian)
            )
        );

        manager = ArrakisStandardManager(
            payable(address(new ERC1967Proxy(implementation, "")))
        );

        // #endregion create a new manager.

        vm.expectRevert(IArrakisStandardManager.AddressZero.selector);

        manager.initialize(owner, defaultReceiver, address(0));
    }

    function testInitialize() public {
        // #region create a new manager.

        address implementation = address(
            new ArrakisStandardManager(
                defaultFeePIPS,
                NATIVE_COIN,
                nativeTokenDecimals,
                address(guardian)
            )
        );

        manager = ArrakisStandardManager(
            payable(address(new ERC1967Proxy(implementation, "")))
        );

        // #endregion create a new manager.

        address owner =
            vm.addr(uint256(keccak256(abi.encode("Owner"))));
        address defaultReceiver = vm.addr(
            uint256(keccak256(abi.encode("Default Receiver")))
        );

        manager.initialize(owner, defaultReceiver, factory);

        assertEq(owner, Ownable(manager).owner());
        assertEq(
            defaultReceiver,
            IArrakisStandardManager(manager).defaultReceiver()
        );
        assertEq(factory, IArrakisStandardManager(manager).factory());
    }

    // #endregion test initialize.

    // #region test pause/unpause.

    function testPausedOnlyOwner() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisStandardManager.OnlyGuardian.selector,
                address(this),
                IGuardian(guardian).pauser()
            )
        );

        manager.pause();
    }

    function testPause() public {
        assertEq(manager.paused(), false);

        vm.prank(IGuardian(guardian).pauser());
        manager.pause();

        assertEq(manager.paused(), true);
    }

    function testUnPauseOnlyOwner() public {
        vm.prank(IGuardian(guardian).pauser());
        manager.pause();

        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisStandardManager.OnlyGuardian.selector,
                address(this),
                IGuardian(guardian).pauser()
            )
        );

        manager.unpause();
    }

    function testUnPauseNotPaused() public {
        assertEq(manager.paused(), false);

        vm.startPrank(IGuardian(guardian).pauser());
        vm.expectRevert(bytes("Pausable: not paused"));
        manager.unpause();
    }

    function testUnPause() public {
        assertEq(manager.paused(), false);

        vm.prank(IGuardian(guardian).pauser());
        manager.pause();

        assertEq(manager.paused(), true);

        vm.prank(IGuardian(guardian).pauser());
        manager.unpause();

        assertEq(manager.paused(), false);
    }

    // #endregion test pause/unpause.

    // #region test setDefaultReceiver.

    function testSetDefaultReceiverOnlyOwner() public {
        address newDefaultReceiver = vm.addr(
            uint256(keccak256(abi.encode("New Default Receiver")))
        );

        vm.expectRevert(Ownable.Unauthorized.selector);

        manager.setDefaultReceiver(newDefaultReceiver);
    }

    function testSetDefaultReceiverAddressZero() public {
        address owner = Ownable(manager).owner();
        vm.prank(owner);
        vm.expectRevert(IArrakisStandardManager.AddressZero.selector);

        manager.setDefaultReceiver(address(0));
    }

    function testSetDefaultReceiver() public {
        address newDefaultReceiver = vm.addr(
            uint256(keccak256(abi.encode("New Default Receiver")))
        );

        assertEq(manager.defaultReceiver(), defaultReceiver);

        address owner = Ownable(manager).owner();
        vm.prank(owner);

        manager.setDefaultReceiver(newDefaultReceiver);

        assertEq(manager.defaultReceiver(), newDefaultReceiver);
    }

    // #endregion test setDefaultReceiver.

    // #region test setReceiverByToken.

    function testSetReceiverByTokenOnlyOwner() public {
        address usdcReceiver =
            vm.addr(uint256(keccak256(abi.encode("USDC Receiver"))));
        address vault =
            vm.addr(uint256(keccak256(abi.encode("Vault"))));
        vm.expectRevert(Ownable.Unauthorized.selector);

        manager.setReceiverByToken(vault, true, usdcReceiver);
    }

    function testSetReceiverByTokenOnlyWhitelisted() public {
        address vault =
            vm.addr(uint256(keccak256(abi.encode("Vault"))));
        address usdcReceiver =
            vm.addr(uint256(keccak256(abi.encode("USDC Receiver"))));
        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisStandardManager.NotWhitelistedVault.selector,
                vault
            )
        );

        vm.prank(owner);

        manager.setReceiverByToken(vault, true, usdcReceiver);
    }

    function testSetReceiverAddressZero() public {
        // #region init management.

        uint24 maxDeviation = TEN_PERCENT; // 10%
        uint256 cooldownPeriod = 60; // 60 seconds.
        address executor =
            vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strategy Announcer")))
        );
        uint24 maxSlippagePIPS = TEN_PERCENT;

        // #region create module.

        LpModuleMock module = new LpModuleMock();

        // #endregion create module.

        // #region create vault.

        ArrakisMetaVaultMock vault = new ArrakisMetaVaultMock();
        vault.setManager(address(manager));
        vault.setModule(address(module));

        // #endregion create vault.

        // #region create oracle.

        address oracle =
            vm.addr(uint256(keccak256(abi.encode("Oracle"))));

        // #endregion create oracle.

        // #region set params.

        SetupParams memory params = SetupParams({
            vault: address(vault),
            oracle: IOracleWrapper(oracle),
            maxDeviation: maxDeviation,
            cooldownPeriod: cooldownPeriod,
            executor: executor,
            stratAnnouncer: stratAnnouncer,
            maxSlippagePIPS: maxSlippagePIPS
        });

        // #endregion set params.

        // #region call through the factory initManagement.

        vm.prank(factory);

        manager.initManagement(params);

        // #endregion call through the factory initManagement.

        // #endregion init management.

        vm.prank(owner);
        manager.setReceiverByToken(address(vault), true, address(0));
    }

    function testSetReceiverByToken() public {
        // #region init management.

        uint24 maxDeviation = TEN_PERCENT; // 10%
        uint256 cooldownPeriod = 60; // 60 seconds.
        address executor =
            vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strategy Announcer")))
        );
        uint24 maxSlippagePIPS = TEN_PERCENT;

        // #region create module.

        LpModuleMock module = new LpModuleMock();

        // #endregion create module.

        // #region create vault.

        ArrakisMetaVaultMock vault = new ArrakisMetaVaultMock();
        vault.setManager(address(manager));
        vault.setModule(address(module));
        vault.setTokenOAndToken1(USDC, WETH);

        // #endregion create vault.

        // #region create oracle.

        address oracle =
            vm.addr(uint256(keccak256(abi.encode("Oracle"))));

        // #endregion create oracle.

        // #region set params.

        SetupParams memory params = SetupParams({
            vault: address(vault),
            oracle: IOracleWrapper(oracle),
            maxDeviation: maxDeviation,
            cooldownPeriod: cooldownPeriod,
            executor: executor,
            stratAnnouncer: stratAnnouncer,
            maxSlippagePIPS: maxSlippagePIPS
        });

        // #endregion set params.

        // #region call through the factory initManagement.

        vm.prank(factory);
        manager.initManagement(params);

        // #endregion call through the factory initManagement.

        // #endregion init management.

        address usdcReceiver =
            vm.addr(uint256(keccak256(abi.encode("USDC Receiver"))));

        assertEq(manager.receiversByToken(USDC), address(0));

        vm.prank(owner);

        manager.setReceiverByToken(address(vault), true, usdcReceiver);

        assertEq(manager.receiversByToken(USDC), usdcReceiver);
    }

    // #endregion test setReceiverByToken.

    // #region test decreaseManagerFeePIPS.

    function testDecreaseManagerFeePIPSOnlyOwner() public {
        // #region init management.

        uint24 maxDeviation = TEN_PERCENT; // 10%
        uint256 cooldownPeriod = 60; // 60 seconds.
        address executor =
            vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strategy Announcer")))
        );
        uint24 maxSlippagePIPS = TEN_PERCENT;

        // #region create module.

        LpModuleMock module = new LpModuleMock();

        // #endregion create module.

        // #region create vault.

        ArrakisMetaVaultMock vault = new ArrakisMetaVaultMock();
        vault.setManager(address(manager));
        vault.setModule(address(module));
        vault.setTokenOAndToken1(USDC, WETH);

        // #endregion create vault.

        // #region create oracle.

        address oracle =
            vm.addr(uint256(keccak256(abi.encode("Oracle"))));

        // #endregion create oracle.

        // #region set params.

        SetupParams memory params = SetupParams({
            vault: address(vault),
            oracle: IOracleWrapper(oracle),
            maxDeviation: maxDeviation,
            cooldownPeriod: cooldownPeriod,
            executor: executor,
            stratAnnouncer: stratAnnouncer,
            maxSlippagePIPS: maxSlippagePIPS
        });

        // #endregion set params.

        // #region call through the factory initManagement.

        vm.prank(factory);
        manager.initManagement(params);

        // #endregion call through the factory initManagement.

        // #endregion init management.

        address usdcReceiver =
            vm.addr(uint256(keccak256(abi.encode("USDC Receiver"))));

        assertEq(manager.receiversByToken(USDC), address(0));

        vm.prank(owner);

        manager.setReceiverByToken(address(vault), true, usdcReceiver);

        assertEq(manager.receiversByToken(USDC), usdcReceiver);

        vm.expectRevert(Ownable.Unauthorized.selector);

        manager.decreaseManagerFeePIPS(
            address(vault), SafeCast.toUint24(defaultFeePIPS / 2)
        );
    }

    function testDecreaseManagerFeePIPSNotWhitelisted() public {
        address vault = vm.addr(
            uint256(keccak256(abi.encode("Arrakis Meta Vault")))
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisStandardManager.NotWhitelistedVault.selector,
                vault
            )
        );
        vm.prank(owner);

        manager.decreaseManagerFeePIPS(
            vault, SafeCast.toUint24(defaultFeePIPS / 2)
        );
    }

    function testDecreaseManagerNotFeeDecrease() public {
        // #region init management.

        uint24 maxDeviation = TEN_PERCENT; // 10%
        uint256 cooldownPeriod = 60; // 60 seconds.
        address executor =
            vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strategy Announcer")))
        );
        uint24 maxSlippagePIPS = TEN_PERCENT;

        // #region create module.

        LpModuleMock module = new LpModuleMock();

        // #endregion create module.

        // #region create vault.

        ArrakisMetaVaultMock vault = new ArrakisMetaVaultMock();
        vault.setManager(address(manager));
        vault.setModule(address(module));
        vault.setTokenOAndToken1(USDC, WETH);

        // #endregion create vault.

        // #region create oracle.

        address oracle =
            vm.addr(uint256(keccak256(abi.encode("Oracle"))));

        // #endregion create oracle.

        // #region set params.

        SetupParams memory params = SetupParams({
            vault: address(vault),
            oracle: IOracleWrapper(oracle),
            maxDeviation: maxDeviation,
            cooldownPeriod: cooldownPeriod,
            executor: executor,
            stratAnnouncer: stratAnnouncer,
            maxSlippagePIPS: maxSlippagePIPS
        });

        // #endregion set params.

        // #region call through the factory initManagement.

        vm.prank(factory);
        manager.initManagement(params);

        // #endregion call through the factory initManagement.

        // #endregion init management.

        address usdcReceiver =
            vm.addr(uint256(keccak256(abi.encode("USDC Receiver"))));

        assertEq(manager.receiversByToken(USDC), address(0));

        vm.prank(owner);

        manager.setReceiverByToken(address(vault), true, usdcReceiver);

        assertEq(manager.receiversByToken(USDC), usdcReceiver);

        vm.expectRevert(
            IArrakisStandardManager.NotFeeDecrease.selector
        );
        vm.prank(owner);

        manager.decreaseManagerFeePIPS(
            address(vault), SafeCast.toUint24(defaultFeePIPS * 2)
        );
    }

    function testDecreaseManager() public {
        // #region init management.

        uint24 maxDeviation = TEN_PERCENT; // 10%
        uint256 cooldownPeriod = 60; // 60 seconds.
        address executor =
            vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strategy Announcer")))
        );
        uint24 maxSlippagePIPS = TEN_PERCENT;

        // #region create module.

        LpModuleMock module = new LpModuleMock();

        // #endregion create module.

        // #region create vault.

        ArrakisMetaVaultMock vault = new ArrakisMetaVaultMock();
        vault.setManager(address(manager));
        vault.setModule(address(module));
        vault.setTokenOAndToken1(USDC, WETH);

        // #endregion create vault.

        // #region create oracle.

        address oracle =
            vm.addr(uint256(keccak256(abi.encode("Oracle"))));

        // #endregion create oracle.

        // #region set params.

        SetupParams memory params = SetupParams({
            vault: address(vault),
            oracle: IOracleWrapper(oracle),
            maxDeviation: maxDeviation,
            cooldownPeriod: cooldownPeriod,
            executor: executor,
            stratAnnouncer: stratAnnouncer,
            maxSlippagePIPS: maxSlippagePIPS
        });

        // #endregion set params.

        // #region call through the factory initManagement.

        vm.prank(factory);
        manager.initManagement(params);

        // #endregion call through the factory initManagement.

        // #endregion init management.

        address usdcReceiver =
            vm.addr(uint256(keccak256(abi.encode("USDC Receiver"))));

        assertEq(manager.receiversByToken(USDC), address(0));

        vm.prank(owner);

        manager.setReceiverByToken(address(vault), true, usdcReceiver);

        assertEq(manager.receiversByToken(USDC), usdcReceiver);

        vm.prank(owner);

        manager.decreaseManagerFeePIPS(
            address(vault), SafeCast.toUint24(defaultFeePIPS / 2)
        );
    }

    // #endregion test decreaseManagerFeePIPS.

    // #region test submitIncreaseManagerFeePIPS.

    function testSubmitIncreaseManagerFeePIPSNotOwner() public {
        // #region init management.

        uint24 maxDeviation = TEN_PERCENT; // 10%
        uint256 cooldownPeriod = 60; // 60 seconds.
        address executor =
            vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strategy Announcer")))
        );
        uint24 maxSlippagePIPS = TEN_PERCENT;

        // #region create module.

        LpModuleMock module = new LpModuleMock();

        // #endregion create module.

        // #region create vault.

        ArrakisMetaVaultMock vault = new ArrakisMetaVaultMock();
        vault.setManager(address(manager));
        vault.setModule(address(module));
        vault.setTokenOAndToken1(USDC, WETH);

        // #endregion create vault.

        // #region create oracle.

        address oracle =
            vm.addr(uint256(keccak256(abi.encode("Oracle"))));

        // #endregion create oracle.

        // #region set params.

        SetupParams memory params = SetupParams({
            vault: address(vault),
            oracle: IOracleWrapper(oracle),
            maxDeviation: maxDeviation,
            cooldownPeriod: cooldownPeriod,
            executor: executor,
            stratAnnouncer: stratAnnouncer,
            maxSlippagePIPS: maxSlippagePIPS
        });

        // #endregion set params.

        // #region call through the factory initManagement.

        vm.prank(factory);
        manager.initManagement(params);

        // #endregion call through the factory initManagement.

        // #endregion init management.

        address usdcReceiver =
            vm.addr(uint256(keccak256(abi.encode("USDC Receiver"))));

        assertEq(manager.receiversByToken(USDC), address(0));

        vm.prank(owner);

        manager.setReceiverByToken(address(vault), true, usdcReceiver);

        assertEq(manager.receiversByToken(USDC), usdcReceiver);

        vm.expectRevert(Ownable.Unauthorized.selector);

        manager.submitIncreaseManagerFeePIPS(
            address(vault), SafeCast.toUint24(defaultFeePIPS * 2)
        );
    }

    function testSubmitIncreaseManagerFeePIPSNotWhitelisted()
        public
    {
        address vault =
            vm.addr(uint256(keccak256(abi.encode("Meta Vault"))));

        address usdcReceiver =
            vm.addr(uint256(keccak256(abi.encode("USDC Receiver"))));

        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisStandardManager.NotWhitelistedVault.selector,
                vault
            )
        );
        vm.prank(owner);

        manager.submitIncreaseManagerFeePIPS(
            vault, SafeCast.toUint24(defaultFeePIPS / 2)
        );
    }

    function testSubmitIncreaseManagerFeePIPSNotFeeDecrease()
        public
    {
        // #region init management.

        uint24 maxDeviation = TEN_PERCENT; // 10%
        uint256 cooldownPeriod = 60; // 60 seconds.
        address executor =
            vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strategy Announcer")))
        );
        uint24 maxSlippagePIPS = TEN_PERCENT;

        // #region create module.

        LpModuleMock module = new LpModuleMock();

        // #endregion create module.

        // #region create vault.

        ArrakisMetaVaultMock vault = new ArrakisMetaVaultMock();
        vault.setManager(address(manager));
        vault.setModule(address(module));
        vault.setTokenOAndToken1(USDC, WETH);

        // #endregion create vault.

        // #region create oracle.

        address oracle =
            vm.addr(uint256(keccak256(abi.encode("Oracle"))));

        // #endregion create oracle.

        // #region set params.

        SetupParams memory params = SetupParams({
            vault: address(vault),
            oracle: IOracleWrapper(oracle),
            maxDeviation: maxDeviation,
            cooldownPeriod: cooldownPeriod,
            executor: executor,
            stratAnnouncer: stratAnnouncer,
            maxSlippagePIPS: maxSlippagePIPS
        });

        // #endregion set params.

        // #region call through the factory initManagement.

        vm.prank(factory);
        manager.initManagement(params);

        // #endregion call through the factory initManagement.

        // #endregion init management.

        address usdcReceiver =
            vm.addr(uint256(keccak256(abi.encode("USDC Receiver"))));
        assertEq(manager.receiversByToken(USDC), address(0));

        vm.prank(owner);

        manager.setReceiverByToken(address(vault), true, usdcReceiver);

        assertEq(manager.receiversByToken(USDC), usdcReceiver);

        vm.expectRevert(
            IArrakisStandardManager.NotFeeIncrease.selector
        );
        vm.prank(owner);

        manager.submitIncreaseManagerFeePIPS(
            address(vault), SafeCast.toUint24(defaultFeePIPS / 2)
        );
    }

    function testSubmitIncreaseManagerFeePIPSAlreadyPending()
        public
    {
        // #region init management.

        uint24 maxDeviation = TEN_PERCENT; // 10%
        uint256 cooldownPeriod = 60; // 60 seconds.
        address executor =
            vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strategy Announcer")))
        );
        uint24 maxSlippagePIPS = TEN_PERCENT;

        // #region create module.

        LpModuleMock module = new LpModuleMock();

        // #endregion create module.

        // #region create vault.

        ArrakisMetaVaultMock vault = new ArrakisMetaVaultMock();
        vault.setManager(address(manager));
        vault.setModule(address(module));
        vault.setTokenOAndToken1(USDC, WETH);

        // #endregion create vault.

        // #region create oracle.

        address oracle =
            vm.addr(uint256(keccak256(abi.encode("Oracle"))));

        // #endregion create oracle.

        // #region set params.

        SetupParams memory params = SetupParams({
            vault: address(vault),
            oracle: IOracleWrapper(oracle),
            maxDeviation: maxDeviation,
            cooldownPeriod: cooldownPeriod,
            executor: executor,
            stratAnnouncer: stratAnnouncer,
            maxSlippagePIPS: maxSlippagePIPS
        });

        // #endregion set params.

        // #region call through the factory initManagement.

        vm.prank(factory);
        manager.initManagement(params);

        // #endregion call through the factory initManagement.

        // #endregion init management.

        address usdcReceiver =
            vm.addr(uint256(keccak256(abi.encode("USDC Receiver"))));

        assertEq(manager.receiversByToken(USDC), address(0));

        vm.prank(owner);

        manager.setReceiverByToken(address(vault), true, usdcReceiver);

        assertEq(manager.receiversByToken(USDC), usdcReceiver);

        vm.prank(owner);

        manager.submitIncreaseManagerFeePIPS(
            address(vault), SafeCast.toUint24(defaultFeePIPS * 2)
        );

        vm.prank(owner);
        vm.expectRevert(
            IArrakisStandardManager.AlreadyPendingIncrease.selector
        );

        manager.submitIncreaseManagerFeePIPS(
            address(vault), SafeCast.toUint24(defaultFeePIPS * 2)
        );
    }

    function testSubmitIncreaseManagerFeePIPS() public {
        // #region init management.

        uint24 maxDeviation = TEN_PERCENT; // 10%
        uint256 cooldownPeriod = 60; // 60 seconds.
        address executor =
            vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strategy Announcer")))
        );
        uint24 maxSlippagePIPS = TEN_PERCENT;

        // #region create module.

        LpModuleMock module = new LpModuleMock();

        // #endregion create module.

        // #region create vault.

        ArrakisMetaVaultMock vault = new ArrakisMetaVaultMock();
        vault.setManager(address(manager));
        vault.setModule(address(module));
        vault.setTokenOAndToken1(USDC, WETH);

        // #endregion create vault.

        // #region create oracle.

        address oracle =
            vm.addr(uint256(keccak256(abi.encode("Oracle"))));

        // #endregion create oracle.

        // #region set params.

        SetupParams memory params = SetupParams({
            vault: address(vault),
            oracle: IOracleWrapper(oracle),
            maxDeviation: maxDeviation,
            cooldownPeriod: cooldownPeriod,
            executor: executor,
            stratAnnouncer: stratAnnouncer,
            maxSlippagePIPS: maxSlippagePIPS
        });

        // #endregion set params.

        // #region call through the factory initManagement.

        vm.prank(factory);
        manager.initManagement(params);

        // #endregion call through the factory initManagement.

        // #endregion init management.

        address usdcReceiver =
            vm.addr(uint256(keccak256(abi.encode("USDC Receiver"))));

        assertEq(manager.receiversByToken(USDC), address(0));

        vm.prank(owner);

        manager.setReceiverByToken(address(vault), true, usdcReceiver);

        assertEq(manager.receiversByToken(USDC), usdcReceiver);

        (uint256 submitTimestamp,) =
            manager.pendingFeeIncrease(address(vault));
        assertEq(submitTimestamp, 0);

        vm.prank(owner);

        manager.submitIncreaseManagerFeePIPS(
            address(vault), SafeCast.toUint24(defaultFeePIPS * 2)
        );

        (submitTimestamp,) =
            manager.pendingFeeIncrease(address(vault));

        assertEq(submitTimestamp, block.timestamp);
    }

    // #endregion test submitIncreaseManagerFeePIPS.

    // #region test finalizeIncreaseManagerFeePIPS.

    function testFinalizeIncreaseManagerFeePIPSOnlyOwner() public {
        // #region init management.

        uint24 maxDeviation = TEN_PERCENT; // 10%
        uint256 cooldownPeriod = 60; // 60 seconds.
        address executor =
            vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strategy Announcer")))
        );
        uint24 maxSlippagePIPS = TEN_PERCENT;

        // #region create module.

        LpModuleMock module = new LpModuleMock();

        // #endregion create module.

        // #region create vault.

        ArrakisMetaVaultMock vault = new ArrakisMetaVaultMock();
        vault.setManager(address(manager));
        vault.setModule(address(module));
        vault.setTokenOAndToken1(USDC, WETH);

        // #endregion create vault.

        // #region create oracle.

        address oracle =
            vm.addr(uint256(keccak256(abi.encode("Oracle"))));

        // #endregion create oracle.

        // #region set params.

        SetupParams memory params = SetupParams({
            vault: address(vault),
            oracle: IOracleWrapper(oracle),
            maxDeviation: maxDeviation,
            cooldownPeriod: cooldownPeriod,
            executor: executor,
            stratAnnouncer: stratAnnouncer,
            maxSlippagePIPS: maxSlippagePIPS
        });

        // #endregion set params.

        // #region call through the factory initManagement.

        vm.prank(factory);
        manager.initManagement(params);

        // #endregion call through the factory initManagement.

        address usdcReceiver =
            vm.addr(uint256(keccak256(abi.encode("USDC Receiver"))));

        // #endregion init management.

        // #region submit increase fees.

        assertEq(manager.receiversByToken(USDC), address(0));

        vm.prank(owner);

        manager.setReceiverByToken(address(vault), true, usdcReceiver);

        assertEq(manager.receiversByToken(USDC), usdcReceiver);

        (uint256 submitTimestamp,) =
            manager.pendingFeeIncrease(address(vault));
        assertEq(submitTimestamp, 0);

        vm.prank(owner);

        manager.submitIncreaseManagerFeePIPS(
            address(vault), SafeCast.toUint24(defaultFeePIPS * 2)
        );

        (submitTimestamp,) =
            manager.pendingFeeIncrease(address(vault));

        assertEq(submitTimestamp, block.timestamp);

        // #endregion submit increase fees.

        vm.expectRevert(Ownable.Unauthorized.selector);

        manager.finalizeIncreaseManagerFeePIPS(address(vault));
    }

    function testFinalizeIncreaseManagerFeePIPSNoPendingIncrease()
        public
    {
        // #region init management.

        uint24 maxDeviation = TEN_PERCENT; // 10%
        uint256 cooldownPeriod = 60; // 60 seconds.
        address executor =
            vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strategy Announcer")))
        );
        uint24 maxSlippagePIPS = TEN_PERCENT;

        // #region create module.

        LpModuleMock module = new LpModuleMock();

        // #endregion create module.

        // #region create vault.

        ArrakisMetaVaultMock vault = new ArrakisMetaVaultMock();
        vault.setManager(address(manager));
        vault.setModule(address(module));
        vault.setTokenOAndToken1(USDC, WETH);

        // #endregion create vault.

        // #region create oracle.

        address oracle =
            vm.addr(uint256(keccak256(abi.encode("Oracle"))));

        // #endregion create oracle.

        // #region set params.

        SetupParams memory params = SetupParams({
            vault: address(vault),
            oracle: IOracleWrapper(oracle),
            maxDeviation: maxDeviation,
            cooldownPeriod: cooldownPeriod,
            executor: executor,
            stratAnnouncer: stratAnnouncer,
            maxSlippagePIPS: maxSlippagePIPS
        });

        // #endregion set params.

        // #region call through the factory initManagement.

        vm.prank(factory);
        manager.initManagement(params);

        // #endregion call through the factory initManagement.

        address usdcReceiver =
            vm.addr(uint256(keccak256(abi.encode("USDC Receiver"))));

        // #endregion init management.

        vm.expectRevert(
            IArrakisStandardManager.NoPendingIncrease.selector
        );
        vm.prank(owner);

        manager.finalizeIncreaseManagerFeePIPS(address(vault));
    }

    function testFinalizeIncreaseManagerFeePIPSTimeNotPassed()
        public
    {
        // #region init management.

        uint24 maxDeviation = TEN_PERCENT; // 10%
        uint256 cooldownPeriod = 60; // 60 seconds.
        address executor =
            vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strategy Announcer")))
        );
        uint24 maxSlippagePIPS = TEN_PERCENT;

        // #region create module.

        LpModuleMock module = new LpModuleMock();

        // #endregion create module.

        // #region create vault.

        ArrakisMetaVaultMock vault = new ArrakisMetaVaultMock();
        vault.setManager(address(manager));
        vault.setModule(address(module));
        vault.setTokenOAndToken1(USDC, WETH);

        // #endregion create vault.

        // #region create oracle.

        address oracle =
            vm.addr(uint256(keccak256(abi.encode("Oracle"))));

        // #endregion create oracle.

        // #region set params.

        SetupParams memory params = SetupParams({
            vault: address(vault),
            oracle: IOracleWrapper(oracle),
            maxDeviation: maxDeviation,
            cooldownPeriod: cooldownPeriod,
            executor: executor,
            stratAnnouncer: stratAnnouncer,
            maxSlippagePIPS: maxSlippagePIPS
        });

        // #endregion set params.

        // #region call through the factory initManagement.

        vm.prank(factory);
        manager.initManagement(params);

        // #endregion call through the factory initManagement.

        address usdcReceiver =
            vm.addr(uint256(keccak256(abi.encode("USDC Receiver"))));

        // #endregion init management.

        // #region submit increase fees.

        assertEq(manager.receiversByToken(USDC), address(0));

        vm.prank(owner);

        manager.setReceiverByToken(address(vault), true, usdcReceiver);

        assertEq(manager.receiversByToken(USDC), usdcReceiver);

        (uint256 submitTimestamp,) =
            manager.pendingFeeIncrease(address(vault));
        assertEq(submitTimestamp, 0);

        vm.prank(owner);

        manager.submitIncreaseManagerFeePIPS(
            address(vault), SafeCast.toUint24(defaultFeePIPS * 2)
        );

        (submitTimestamp,) =
            manager.pendingFeeIncrease(address(vault));

        assertEq(submitTimestamp, block.timestamp);

        // #endregion submit increase fees.

        vm.expectRevert(
            IArrakisStandardManager.TimeNotPassed.selector
        );
        vm.prank(owner);

        manager.finalizeIncreaseManagerFeePIPS(address(vault));
    }

    function testFinalizeIncreaseManagerFeePIPS() public {
        // #region init management.

        uint24 maxDeviation = TEN_PERCENT; // 10%
        uint256 cooldownPeriod = 60; // 60 seconds.
        address executor =
            vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strategy Announcer")))
        );
        uint24 maxSlippagePIPS = TEN_PERCENT;

        // #region create module.

        LpModuleMock module = new LpModuleMock();

        // #endregion create module.

        // #region create vault.

        ArrakisMetaVaultMock vault = new ArrakisMetaVaultMock();
        vault.setManager(address(manager));
        vault.setModule(address(module));
        vault.setTokenOAndToken1(USDC, WETH);

        // #endregion create vault.

        // #region create oracle.

        address oracle =
            vm.addr(uint256(keccak256(abi.encode("Oracle"))));

        // #endregion create oracle.

        // #region set params.

        SetupParams memory params = SetupParams({
            vault: address(vault),
            oracle: IOracleWrapper(oracle),
            maxDeviation: maxDeviation,
            cooldownPeriod: cooldownPeriod,
            executor: executor,
            stratAnnouncer: stratAnnouncer,
            maxSlippagePIPS: maxSlippagePIPS
        });

        // #endregion set params.

        // #region call through the factory initManagement.

        vm.prank(factory);
        manager.initManagement(params);

        // #endregion call through the factory initManagement.

        address usdcReceiver =
            vm.addr(uint256(keccak256(abi.encode("USDC Receiver"))));

        // #endregion init management.

        // #region submit increase fees.

        assertEq(manager.receiversByToken(USDC), address(0));

        vm.prank(owner);

        manager.setReceiverByToken(address(vault), true, usdcReceiver);

        assertEq(manager.receiversByToken(USDC), usdcReceiver);

        (uint256 submitTimestamp,) =
            manager.pendingFeeIncrease(address(vault));
        assertEq(submitTimestamp, 0);

        vm.prank(owner);

        manager.submitIncreaseManagerFeePIPS(
            address(vault), SafeCast.toUint24(defaultFeePIPS * 2)
        );

        (submitTimestamp,) =
            manager.pendingFeeIncrease(address(vault));

        assertEq(submitTimestamp, block.timestamp);

        // #endregion submit increase fees.

        vm.prank(owner);
        vm.warp(block.timestamp + WEEK + 1);

        manager.finalizeIncreaseManagerFeePIPS(address(vault));
    }

    // #endregion test finalizeIncreaseManagerFeePIPS.

    // #region test withdrawManagerBalance.

    function testWithdrawManagerBalanceOnlyOwner() public {
        address vault =
            vm.addr(uint256(keccak256(abi.encode("Meta Vault"))));
        vm.expectRevert(Ownable.Unauthorized.selector);

        manager.withdrawManagerBalance(vault);
    }

    function testWithdrawManagerBalanceUSDC() public {
        // #region init management.

        uint24 maxDeviation = TEN_PERCENT; // 10%
        uint256 cooldownPeriod = 60; // 60 seconds.
        address executor =
            vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strategy Announcer")))
        );
        uint24 maxSlippagePIPS = TEN_PERCENT;

        // #region create module.

        LpModuleMock module = new LpModuleMock();

        // #endregion create module.

        // #region create vault.

        ArrakisMetaVaultMock vault = new ArrakisMetaVaultMock();
        vault.setManager(address(manager));
        vault.setModule(address(module));
        vault.setTokenOAndToken1(USDC, WETH);

        // #endregion create vault.

        // #region create oracle.

        address oracle =
            vm.addr(uint256(keccak256(abi.encode("Oracle"))));

        // #endregion create oracle.

        // #region set params.

        SetupParams memory params = SetupParams({
            vault: address(vault),
            oracle: IOracleWrapper(oracle),
            maxDeviation: maxDeviation,
            cooldownPeriod: cooldownPeriod,
            executor: executor,
            stratAnnouncer: stratAnnouncer,
            maxSlippagePIPS: maxSlippagePIPS
        });

        // #endregion set params.

        // #region call through the factory initManagement.

        vm.prank(factory);
        manager.initManagement(params);

        // #endregion call through the factory initManagement.

        address usdcReceiver =
            vm.addr(uint256(keccak256(abi.encode("USDC Receiver"))));

        // #endregion init management.

        // #region mock usdc fees on module.

        module.setToken0AndToken1(USDC, WETH);
        module.setManager(address(manager));
        deal(USDC, address(module), 2000e6);

        // #endregion mock usdc fees on module.

        vm.prank(owner);

        manager.setReceiverByToken(address(vault), true, usdcReceiver);

        assertEq(IERC20(USDC).balanceOf(usdcReceiver), 0);

        vm.prank(owner);

        (uint256 usdcManagerFee,) =
            manager.withdrawManagerBalance(address(vault));

        assertEq(IERC20(USDC).balanceOf(usdcReceiver), usdcManagerFee);
        assertEq(IERC20(USDC).balanceOf(usdcReceiver), 2000e6);
    }

    function testWithdrawManagerBalanceETHAsToken0() public {
        // #region init management.

        uint24 maxDeviation = TEN_PERCENT; // 10%
        uint256 cooldownPeriod = 60; // 60 seconds.
        address executor =
            vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strategy Announcer")))
        );
        uint24 maxSlippagePIPS = TEN_PERCENT;

        // #region create module.

        LpModuleMock module = new LpModuleMock();

        // #endregion create module.

        // #region create vault.

        ArrakisMetaVaultMock vault = new ArrakisMetaVaultMock();
        vault.setManager(address(manager));
        vault.setModule(address(module));
        vault.setTokenOAndToken1(NATIVE_COIN, WETH);

        // #endregion create vault.

        // #region create oracle.

        address oracle =
            vm.addr(uint256(keccak256(abi.encode("Oracle"))));

        // #endregion create oracle.

        // #region set params.

        SetupParams memory params = SetupParams({
            vault: address(vault),
            oracle: IOracleWrapper(oracle),
            maxDeviation: maxDeviation,
            cooldownPeriod: cooldownPeriod,
            executor: executor,
            stratAnnouncer: stratAnnouncer,
            maxSlippagePIPS: maxSlippagePIPS
        });

        // #endregion set params.

        // #region call through the factory initManagement.

        vm.prank(factory);
        manager.initManagement(params);

        // #endregion call through the factory initManagement.

        address usdcReceiver =
            vm.addr(uint256(keccak256(abi.encode("USDC Receiver"))));

        // #endregion init management.

        // #region mock usdc fees on module.

        module.setToken0AndToken1(NATIVE_COIN, WETH);
        module.setManager(address(manager));
        vm.deal(address(module), 1 ether);

        // #endregion mock usdc fees on module.

        assertEq(defaultReceiver.balance, 0);

        vm.prank(owner);

        uint256 g = gasleft();

        (uint256 ethManagerFee,) =
            manager.withdrawManagerBalance(address(vault));

        console.logString(
            "Withdraw manager balances, only eth withdrawal (gas): "
        );
        console.logUint(g - gasleft());

        assertEq(defaultReceiver.balance, ethManagerFee);
        assertEq(defaultReceiver.balance, 1 ether);
    }

    function testWithdrawManagerBalanceETHAsToken1() public {
        // #region init management.

        uint24 maxDeviation = TEN_PERCENT; // 10%
        uint256 cooldownPeriod = 60; // 60 seconds.
        address executor =
            vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strategy Announcer")))
        );
        uint24 maxSlippagePIPS = TEN_PERCENT;

        // #region create module.

        LpModuleMock module = new LpModuleMock();

        // #endregion create module.

        // #region create vault.

        ArrakisMetaVaultMock vault = new ArrakisMetaVaultMock();
        vault.setManager(address(manager));
        vault.setModule(address(module));
        vault.setTokenOAndToken1(USDC, NATIVE_COIN);

        // #endregion create vault.

        // #region create oracle.

        address oracle =
            vm.addr(uint256(keccak256(abi.encode("Oracle"))));

        // #endregion create oracle.

        // #region set params.

        SetupParams memory params = SetupParams({
            vault: address(vault),
            oracle: IOracleWrapper(oracle),
            maxDeviation: maxDeviation,
            cooldownPeriod: cooldownPeriod,
            executor: executor,
            stratAnnouncer: stratAnnouncer,
            maxSlippagePIPS: maxSlippagePIPS
        });

        // #endregion set params.

        // #region call through the factory initManagement.

        vm.prank(factory);
        manager.initManagement(params);

        // #endregion call through the factory initManagement.

        address usdcReceiver =
            vm.addr(uint256(keccak256(abi.encode("USDC Receiver"))));

        // #endregion init management.

        // #region mock usdc fees on module.

        module.setToken0AndToken1(USDC, NATIVE_COIN);
        module.setManager(address(manager));
        vm.deal(address(module), 1 ether);

        // #endregion mock usdc fees on module.

        assertEq(defaultReceiver.balance, 0);

        vm.prank(owner);

        uint256 g = gasleft();

        (, uint256 ethManagerFee) =
            manager.withdrawManagerBalance(address(vault));

        console.logString(
            "Withdraw manager balances, only eth withdrawal (gas): "
        );
        console.logUint(g - gasleft());

        assertEq(defaultReceiver.balance, ethManagerFee);
        assertEq(defaultReceiver.balance, 1 ether);
    }

    function testWithdrawManagerBalanceUSDCWETH() public {
        // #region init management.

        uint24 maxDeviation = TEN_PERCENT; // 10%
        uint256 cooldownPeriod = 60; // 60 seconds.
        address executor =
            vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strategy Announcer")))
        );
        uint24 maxSlippagePIPS = TEN_PERCENT;

        // #region create module.

        LpModuleMock module = new LpModuleMock();

        // #endregion create module.

        // #region create vault.

        ArrakisMetaVaultMock vault = new ArrakisMetaVaultMock();
        vault.setManager(address(manager));
        vault.setModule(address(module));
        vault.setTokenOAndToken1(USDC, WETH);

        // #endregion create vault.

        // #region create oracle.

        address oracle =
            vm.addr(uint256(keccak256(abi.encode("Oracle"))));

        // #endregion create oracle.

        // #region set params.

        SetupParams memory params = SetupParams({
            vault: address(vault),
            oracle: IOracleWrapper(oracle),
            maxDeviation: maxDeviation,
            cooldownPeriod: cooldownPeriod,
            executor: executor,
            stratAnnouncer: stratAnnouncer,
            maxSlippagePIPS: maxSlippagePIPS
        });

        // #endregion set params.

        // #region call through the factory initManagement.

        vm.prank(factory);
        manager.initManagement(params);

        // #endregion call through the factory initManagement.

        address usdcReceiver =
            vm.addr(uint256(keccak256(abi.encode("USDC Receiver"))));

        // #endregion init management.

        // #region mock usdc fees on module.

        module.setToken0AndToken1(USDC, WETH);
        module.setManager(address(manager));
        deal(USDC, address(module), 2000e6);
        deal(WETH, address(module), 1e18);

        // #endregion mock usdc fees on module.

        vm.prank(owner);

        manager.setReceiverByToken(address(vault), true, usdcReceiver);

        assertEq(IERC20(USDC).balanceOf(usdcReceiver), 0);
        assertEq(IERC20(WETH).balanceOf(defaultReceiver), 0);

        vm.prank(owner);

        (uint256 usdcManagerFee, uint256 wethManagerFee) =
            manager.withdrawManagerBalance(address(vault));

        assertEq(IERC20(USDC).balanceOf(usdcReceiver), usdcManagerFee);
        assertEq(IERC20(USDC).balanceOf(usdcReceiver), 2000e6);
        assertEq(
            IERC20(WETH).balanceOf(defaultReceiver), wethManagerFee
        );
        assertEq(IERC20(WETH).balanceOf(defaultReceiver), 1e18);
    }

    // #endregion test withdrawManagerBalance.

    // #region test setModule.

    function testSetModuleOnlyExecutor() public {
        address vault =
            vm.addr(uint256(keccak256(abi.encode("Meta Vault"))));
        address module =
            vm.addr(uint256(keccak256(abi.encode("Module"))));
        bytes[] memory payloads = new bytes[](0);

        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisStandardManager.NotWhitelistedVault.selector,
                vault
            )
        );

        manager.setModule(vault, module, payloads);
    }

    function testSetModuleNotExecutor() public {
        // #region init management.

        uint24 maxDeviation = TEN_PERCENT; // 10%
        uint256 cooldownPeriod = 60; // 60 seconds.
        address executor =
            vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strategy Announcer")))
        );
        uint24 maxSlippagePIPS = TEN_PERCENT;

        // #region create module.

        LpModuleMock module = new LpModuleMock();

        // #endregion create module.

        // #region create vault.

        ArrakisMetaVaultMock vault = new ArrakisMetaVaultMock();
        vault.setManager(address(manager));
        vault.setModule(address(module));
        vault.setTokenOAndToken1(USDC, WETH);

        // #endregion create vault.

        // #region create oracle.

        address oracle =
            vm.addr(uint256(keccak256(abi.encode("Oracle"))));

        // #endregion create oracle.

        // #region set params.

        SetupParams memory params = SetupParams({
            vault: address(vault),
            oracle: IOracleWrapper(oracle),
            maxDeviation: maxDeviation,
            cooldownPeriod: cooldownPeriod,
            executor: executor,
            stratAnnouncer: stratAnnouncer,
            maxSlippagePIPS: maxSlippagePIPS
        });

        // #endregion set params.

        // #region call through the factory initManagement.

        vm.prank(factory);
        manager.initManagement(params);

        // #endregion call through the factory initManagement.

        address usdcReceiver =
            vm.addr(uint256(keccak256(abi.encode("USDC Receiver"))));

        // #endregion init management.

        address anotherModule =
            vm.addr(uint256(keccak256(abi.encode("Another Module"))));
        bytes[] memory payloads = new bytes[](0);

        vm.expectRevert(IArrakisStandardManager.NotExecutor.selector);

        manager.setModule(address(vault), anotherModule, payloads);
    }

    function testSetModule() public {
        // #region init management.

        uint24 maxDeviation = TEN_PERCENT; // 10%
        uint256 cooldownPeriod = 60; // 60 seconds.
        address executor =
            vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strategy Announcer")))
        );
        uint24 maxSlippagePIPS = TEN_PERCENT;

        // #region create module.

        LpModuleMock module = new LpModuleMock();

        // #endregion create module.

        // #region create vault.

        ArrakisMetaVaultMock vault = new ArrakisMetaVaultMock();
        vault.setManager(address(manager));
        vault.setModule(address(module));
        vault.setTokenOAndToken1(USDC, WETH);

        // #endregion create vault.

        // #region create oracle.

        address oracle =
            vm.addr(uint256(keccak256(abi.encode("Oracle"))));

        // #endregion create oracle.

        // #region set params.

        SetupParams memory params = SetupParams({
            vault: address(vault),
            oracle: IOracleWrapper(oracle),
            maxDeviation: maxDeviation,
            cooldownPeriod: cooldownPeriod,
            executor: executor,
            stratAnnouncer: stratAnnouncer,
            maxSlippagePIPS: maxSlippagePIPS
        });

        // #endregion set params.

        // #region call through the factory initManagement.

        vm.prank(factory);
        manager.initManagement(params);

        // #endregion call through the factory initManagement.

        // #endregion init management.

        address anotherModule =
            vm.addr(uint256(keccak256(abi.encode("Another Module"))));
        bytes[] memory payloads = new bytes[](0);
        vm.prank(executor);

        manager.setModule(address(vault), anotherModule, payloads);

        assertEq(address(vault.module()), anotherModule);
    }

    // #endregion test setModule.

    // #region test initManagement.

    function testInitManagementOnlyVaultOwner() public {
        address caller = vm.addr(
            uint256(
                keccak256(abi.encode("Not the owner of the vault"))
            )
        );

        // #region init management.

        uint24 maxDeviation = TEN_PERCENT; // 10%
        uint256 cooldownPeriod = 60; // 60 seconds.
        address executor =
            vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strategy Announcer")))
        );
        uint24 maxSlippagePIPS = TEN_PERCENT;

        // #region create module.

        LpModuleMock module = new LpModuleMock();

        // #endregion create module.

        // #region create vault.

        ArrakisMetaVaultMock vault = new ArrakisMetaVaultMock();
        vault.setManager(address(manager));
        vault.setModule(address(module));
        vault.setTokenOAndToken1(USDC, WETH);

        // #endregion create vault.

        // #region create oracle.

        address oracle =
            vm.addr(uint256(keccak256(abi.encode("Oracle"))));

        // #endregion create oracle.

        // #region set params.

        SetupParams memory params = SetupParams({
            vault: address(vault),
            oracle: IOracleWrapper(oracle),
            maxDeviation: maxDeviation,
            cooldownPeriod: cooldownPeriod,
            executor: executor,
            stratAnnouncer: stratAnnouncer,
            maxSlippagePIPS: maxSlippagePIPS
        });

        // #endregion set params.

        // #region call through the factory initManagement.

        vm.prank(caller);
        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisStandardManager.OnlyFactory.selector,
                caller,
                factory
            )
        );
        manager.initManagement(params);

        // #endregion call through the factory initManagement.

        // #endregion init management.
    }

    function testInitManagementVaultAddressZero() public {
        // #region init management.

        uint24 maxDeviation = TEN_PERCENT; // 10%
        uint256 cooldownPeriod = 60; // 60 seconds.
        address executor =
            vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strategy Announcer")))
        );
        uint24 maxSlippagePIPS = TEN_PERCENT;

        // #region create oracle.

        address oracle =
            vm.addr(uint256(keccak256(abi.encode("Oracle"))));

        // #endregion create oracle.

        // #region set params.

        SetupParams memory params = SetupParams({
            vault: address(0),
            oracle: IOracleWrapper(oracle),
            maxDeviation: maxDeviation,
            cooldownPeriod: cooldownPeriod,
            executor: executor,
            stratAnnouncer: stratAnnouncer,
            maxSlippagePIPS: maxSlippagePIPS
        });

        // #endregion set params.

        // #region call through the factory initManagement.

        vm.expectRevert(IArrakisStandardManager.AddressZero.selector);
        vm.prank(factory);
        manager.initManagement(params);

        // #endregion call through the factory initManagement.

        // #endregion init management.
    }

    function testInitManagementVaultAlreadyInManagement() public {
        // #region init management.

        uint24 maxDeviation = TEN_PERCENT; // 10%
        uint256 cooldownPeriod = 60; // 60 seconds.
        address executor =
            vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strategy Announcer")))
        );
        uint24 maxSlippagePIPS = TEN_PERCENT;

        // #region create module.

        LpModuleMock module = new LpModuleMock();

        // #endregion create module.

        // #region create vault.

        ArrakisMetaVaultMock vault = new ArrakisMetaVaultMock();
        vault.setManager(address(manager));
        vault.setModule(address(module));
        vault.setTokenOAndToken1(USDC, WETH);

        // #endregion create vault.

        // #region create oracle.

        address oracle =
            vm.addr(uint256(keccak256(abi.encode("Oracle"))));

        // #endregion create oracle.

        // #region set params.

        SetupParams memory params = SetupParams({
            vault: address(vault),
            oracle: IOracleWrapper(oracle),
            maxDeviation: maxDeviation,
            cooldownPeriod: cooldownPeriod,
            executor: executor,
            stratAnnouncer: stratAnnouncer,
            maxSlippagePIPS: maxSlippagePIPS
        });

        // #endregion set params.

        // #region call through the factory initManagement.

        vm.startPrank(factory);
        manager.initManagement(params);

        // #endregion call through the factory initManagement.

        // #region second call for the same vault.

        vm.expectRevert(
            IArrakisStandardManager.AlreadyInManagement.selector
        );
        manager.initManagement(params);
        vm.stopPrank();

        // #endregion second call for the same vault.

        // #endregion init management.
    }

    function testInitManagementVaultNotDeployed() public {
        // #region init management.

        uint24 maxDeviation = TEN_PERCENT; // 10%
        uint256 cooldownPeriod = 60; // 60 seconds.
        address executor =
            vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strategy Announcer")))
        );
        uint24 maxSlippagePIPS = TEN_PERCENT;

        // #region create oracle.

        address oracle =
            vm.addr(uint256(keccak256(abi.encode("Oracle"))));

        // #endregion create oracle.

        // #region set params.

        address vault =
            vm.addr(uint256(keccak256(abi.encode("Meta Vault"))));

        SetupParams memory params = SetupParams({
            vault: vault,
            oracle: IOracleWrapper(oracle),
            maxDeviation: maxDeviation,
            cooldownPeriod: cooldownPeriod,
            executor: executor,
            stratAnnouncer: stratAnnouncer,
            maxSlippagePIPS: maxSlippagePIPS
        });

        // #endregion set params.

        // #region call through the factory initManagement.

        vm.expectRevert(
            IArrakisStandardManager.VaultNotDeployed.selector
        );
        vm.prank(factory);
        manager.initManagement(params);

        // #endregion call through the factory initManagement.

        // #endregion init management.
    }

    function testInitManagementNotManager() public {
        // #region init management.

        uint24 maxDeviation = TEN_PERCENT; // 10%
        uint256 cooldownPeriod = 60; // 60 seconds.
        address executor =
            vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strategy Announcer")))
        );
        uint24 maxSlippagePIPS = TEN_PERCENT;

        // #region create module.

        LpModuleMock module = new LpModuleMock();

        // #endregion create module.

        // #region create vault.

        address anotherManager =
            vm.addr(uint256(keccak256(abi.encode("Another Manager"))));

        ArrakisMetaVaultMock vault = new ArrakisMetaVaultMock();
        vault.setManager(anotherManager);
        vault.setModule(address(module));
        vault.setTokenOAndToken1(USDC, WETH);

        // #endregion create vault.

        // #region create oracle.

        address oracle =
            vm.addr(uint256(keccak256(abi.encode("Oracle"))));

        // #endregion create oracle.

        // #region set params.

        SetupParams memory params = SetupParams({
            vault: address(vault),
            oracle: IOracleWrapper(oracle),
            maxDeviation: maxDeviation,
            cooldownPeriod: cooldownPeriod,
            executor: executor,
            stratAnnouncer: stratAnnouncer,
            maxSlippagePIPS: maxSlippagePIPS
        });

        // #endregion set params.

        // #region call through the factory initManagement.

        vm.startPrank(factory);
        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisStandardManager.NotTheManager.selector,
                address(manager),
                anotherManager
            )
        );
        manager.initManagement(params);

        // #endregion call through the factory initManagement.

        // #endregion init management.
    }

    function testInitManagementOracleAddressZero() public {
        // #region init management.

        uint24 maxDeviation = TEN_PERCENT; // 10%
        uint256 cooldownPeriod = 60; // 60 seconds.
        address executor =
            vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strategy Announcer")))
        );
        uint24 maxSlippagePIPS = TEN_PERCENT;

        // #region create module.

        LpModuleMock module = new LpModuleMock();

        // #endregion create module.

        // #region create vault.

        ArrakisMetaVaultMock vault = new ArrakisMetaVaultMock();
        vault.setManager(address(manager));
        vault.setModule(address(module));
        vault.setTokenOAndToken1(USDC, WETH);

        // #endregion create vault.

        // #region set params.

        SetupParams memory params = SetupParams({
            vault: address(vault),
            oracle: IOracleWrapper(address(0)),
            maxDeviation: maxDeviation,
            cooldownPeriod: cooldownPeriod,
            executor: executor,
            stratAnnouncer: stratAnnouncer,
            maxSlippagePIPS: maxSlippagePIPS
        });

        // #endregion set params.

        // #region call through the factory initManagement.

        vm.startPrank(factory);
        vm.expectRevert(IArrakisStandardManager.AddressZero.selector);
        manager.initManagement(params);

        // #endregion call through the factory initManagement.

        // #endregion init management.
    }

    function testInitManagementSlippagerGtTenPercent() public {
        // #region init management.

        uint24 maxDeviation = TEN_PERCENT; // 10%
        uint256 cooldownPeriod = 60; // 60 seconds.
        address executor =
            vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strategy Announcer")))
        );
        uint24 maxSlippagePIPS = TEN_PERCENT * 2;

        // #region create module.

        LpModuleMock module = new LpModuleMock();

        // #endregion create module.

        // #region create vault.

        ArrakisMetaVaultMock vault = new ArrakisMetaVaultMock();
        vault.setManager(address(manager));
        vault.setModule(address(module));
        vault.setTokenOAndToken1(USDC, WETH);

        // #endregion create vault.

        // #region create oracle.

        address oracle =
            vm.addr(uint256(keccak256(abi.encode("Oracle"))));

        // #endregion create oracle.

        // #region set params.

        SetupParams memory params = SetupParams({
            vault: address(vault),
            oracle: IOracleWrapper(oracle),
            maxDeviation: maxDeviation,
            cooldownPeriod: cooldownPeriod,
            executor: executor,
            stratAnnouncer: stratAnnouncer,
            maxSlippagePIPS: maxSlippagePIPS
        });

        // #endregion set params.

        // #region call through the factory initManagement.

        vm.startPrank(factory);
        vm.expectRevert(
            IArrakisStandardManager.SlippageTooHigh.selector
        );
        manager.initManagement(params);

        // #endregion call through the factory initManagement.

        // #endregion init management.
    }

    function testInitManagementCooldownPeriodZero() public {
        // #region init management.

        uint24 maxDeviation = TEN_PERCENT; // 10%
        uint256 cooldownPeriod = 0; // 60 seconds.
        address executor =
            vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strategy Announcer")))
        );
        uint24 maxSlippagePIPS = TEN_PERCENT;

        // #region create module.

        LpModuleMock module = new LpModuleMock();

        // #endregion create module.

        // #region create vault.

        ArrakisMetaVaultMock vault = new ArrakisMetaVaultMock();
        vault.setManager(address(manager));
        vault.setModule(address(module));
        vault.setTokenOAndToken1(USDC, WETH);

        // #endregion create vault.

        // #region create oracle.

        address oracle =
            vm.addr(uint256(keccak256(abi.encode("Oracle"))));

        // #endregion create oracle.

        // #region set params.

        SetupParams memory params = SetupParams({
            vault: address(vault),
            oracle: IOracleWrapper(oracle),
            maxDeviation: maxDeviation,
            cooldownPeriod: cooldownPeriod,
            executor: executor,
            stratAnnouncer: stratAnnouncer,
            maxSlippagePIPS: maxSlippagePIPS
        });

        // #endregion set params.

        // #region call through the factory initManagement.

        vm.startPrank(factory);
        vm.expectRevert(
            IArrakisStandardManager.CooldownPeriodSetToZero.selector
        );
        manager.initManagement(params);

        // #endregion call through the factory initManagement.

        // #endregion init management.
    }

    function testInitManagement() public {
        // #region init management.

        uint24 maxDeviation = TEN_PERCENT; // 10%
        uint256 cooldownPeriod = 60; // 60 seconds.
        address executor =
            vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strategy Announcer")))
        );
        uint24 maxSlippagePIPS = TEN_PERCENT;
        ArrakisMetaVaultMock vault;

        {
            // #region create module.

            LpModuleMock module = new LpModuleMock();

            // #endregion create module.

            // #region create vault.

            vault = new ArrakisMetaVaultMock();
            vault.setManager(address(manager));
            vault.setModule(address(module));

            // #endregion create vault.
        }

        // #region create oracle.

        address oracle =
            vm.addr(uint256(keccak256(abi.encode("Oracle"))));

        // #endregion create oracle.

        {
            // #region set params.

            SetupParams memory params = SetupParams({
                vault: address(vault),
                oracle: IOracleWrapper(oracle),
                maxDeviation: maxDeviation,
                cooldownPeriod: cooldownPeriod,
                executor: executor,
                stratAnnouncer: stratAnnouncer,
                maxSlippagePIPS: maxSlippagePIPS
            });

            // #endregion set params.

            // #region call through the factory initManagement.

            vm.prank(factory);
            manager.initManagement(params);

            // #endregion call through the factory initManagement.
        }

        // #endregion init management.

        // #region assertions.

        (
            ,
            uint256 actualCooldownPeriod,
            IOracleWrapper actualOracle,
            uint24 actualMaxDeviation,
            address actualExecutor,
            address actualStratAnnouncer,
            uint24 actualMaxSlippagePIPS,
            uint24 actualManagerFeePIPS
        ) = manager.vaultInfo(address(vault));

        assertEq(address(actualOracle), oracle);
        assertEq(actualMaxDeviation, maxDeviation);
        assertEq(actualCooldownPeriod, cooldownPeriod);
        assertEq(actualExecutor, executor);
        assertEq(actualStratAnnouncer, stratAnnouncer);
        assertEq(actualMaxSlippagePIPS, maxSlippagePIPS);
        assertEq(actualManagerFeePIPS, defaultFeePIPS);

        // #endregion assertions.
    }

    // #endregion test initManagement.

    // #region test updateVaultInfo.

    function testUpdateVaultInfoOnlyWhitelistedVault() public {
        // #region update management.

        uint24 maxDeviation = TEN_PERCENT; // 10%
        uint256 cooldownPeriod = 60; // 60 seconds.
        address executor =
            vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strategy Announcer")))
        );
        uint24 maxSlippagePIPS = TEN_PERCENT;
        ArrakisMetaVaultMock vault;

        {
            // #region create module.

            LpModuleMock module = new LpModuleMock();

            // #endregion create module.

            // #region create vault.

            vault = new ArrakisMetaVaultMock();
            vault.setManager(address(manager));
            vault.setModule(address(module));

            // #endregion create vault.
        }

        // #region create oracle.

        address oracle =
            vm.addr(uint256(keccak256(abi.encode("Oracle"))));

        // #endregion create oracle.

        {
            // #region set params.

            SetupParams memory params = SetupParams({
                vault: address(vault),
                oracle: IOracleWrapper(oracle),
                maxDeviation: maxDeviation,
                cooldownPeriod: cooldownPeriod,
                executor: executor,
                stratAnnouncer: stratAnnouncer,
                maxSlippagePIPS: maxSlippagePIPS
            });

            // #endregion set params.

            // #region call updateVault.

            vm.expectRevert(
                abi.encodeWithSelector(
                    IArrakisStandardManager
                        .NotWhitelistedVault
                        .selector,
                    address(vault)
                )
            );
            manager.updateVaultInfo(params);

            // #endregion call updateVault.
        }

        // #endregion update management.
    }

    function testUpdateVaultInfoOnlyVaultOwner() public {
        // #region update management.

        uint24 maxDeviation = TEN_PERCENT; // 10%
        uint256 cooldownPeriod = 60; // 60 seconds.
        address executor =
            vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strategy Announcer")))
        );
        uint24 maxSlippagePIPS = TEN_PERCENT;
        address vaultOwner =
            vm.addr(uint256(keccak256(abi.encode("Vault Owner"))));
        ArrakisMetaVaultMock vault;

        {
            // #region create module.

            LpModuleMock module = new LpModuleMock();

            // #endregion create module.

            // #region create vault.

            vault = new ArrakisMetaVaultMock();
            vault.setManager(address(manager));
            vault.setModule(address(module));
            vault.setOwner(vaultOwner);

            // #endregion create vault.
        }

        // #region create oracle.

        address oracle =
            vm.addr(uint256(keccak256(abi.encode("Oracle"))));

        // #endregion create oracle.
        SetupParams memory params;
        {
            // #region set params.

            params = SetupParams({
                vault: address(vault),
                oracle: IOracleWrapper(oracle),
                maxDeviation: maxDeviation,
                cooldownPeriod: cooldownPeriod,
                executor: executor,
                stratAnnouncer: stratAnnouncer,
                maxSlippagePIPS: maxSlippagePIPS
            });

            // #endregion set params.

            // #region call initManagement.

            vm.prank(factory);
            manager.initManagement(params);

            // #endregion call initManagement.
        }

        // #region update management.

        {
            cooldownPeriod = cooldownPeriod * 2;

            params = SetupParams({
                vault: address(vault),
                oracle: IOracleWrapper(oracle),
                maxDeviation: maxDeviation,
                cooldownPeriod: cooldownPeriod,
                executor: executor,
                stratAnnouncer: stratAnnouncer,
                maxSlippagePIPS: maxSlippagePIPS
            });

            vm.expectRevert(
                abi.encodeWithSelector(
                    IArrakisStandardManager.OnlyVaultOwner.selector,
                    address(this),
                    vaultOwner
                )
            );

            manager.updateVaultInfo(params);
        }

        // #endregion update management.

        // #endregion update management.
    }

    function testUpdateVaultInfo() public {
        // #region update management.

        uint24 maxDeviation = TEN_PERCENT; // 10%
        uint256 cooldownPeriod = 60; // 60 seconds.
        address executor =
            vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strategy Announcer")))
        );
        uint24 maxSlippagePIPS = TEN_PERCENT;
        address vaultOwner =
            vm.addr(uint256(keccak256(abi.encode("Vault Owner"))));
        ArrakisMetaVaultMock vault;

        {
            // #region create module.

            LpModuleMock module = new LpModuleMock();

            // #endregion create module.

            // #region create vault.

            vault = new ArrakisMetaVaultMock();
            vault.setManager(address(manager));
            vault.setModule(address(module));
            vault.setOwner(vaultOwner);

            // #endregion create vault.
        }

        // #region create oracle.

        address oracle =
            vm.addr(uint256(keccak256(abi.encode("Oracle"))));

        // #endregion create oracle.
        SetupParams memory params;
        {
            // #region set params.

            params = SetupParams({
                vault: address(vault),
                oracle: IOracleWrapper(oracle),
                maxDeviation: maxDeviation,
                cooldownPeriod: cooldownPeriod,
                executor: executor,
                stratAnnouncer: stratAnnouncer,
                maxSlippagePIPS: maxSlippagePIPS
            });

            // #endregion set params.

            // #region call initManagement.

            vm.prank(factory);
            manager.initManagement(params);

            // #endregion call initManagement.
        }

        (, uint256 actualCooldownPeriod,,,,,,) =
            manager.vaultInfo(address(vault));

        assertEq(actualCooldownPeriod, cooldownPeriod);

        // #region update management.

        {
            cooldownPeriod = cooldownPeriod * 2;

            params = SetupParams({
                vault: address(vault),
                oracle: IOracleWrapper(oracle),
                maxDeviation: maxDeviation,
                cooldownPeriod: cooldownPeriod,
                executor: executor,
                stratAnnouncer: stratAnnouncer,
                maxSlippagePIPS: maxSlippagePIPS
            });

            vm.prank(vaultOwner);

            manager.updateVaultInfo(params);
        }

        // #endregion update management.

        // #region assertions.

        (, actualCooldownPeriod,,,,,,) =
            manager.vaultInfo(address(vault));

        assertEq(actualCooldownPeriod, cooldownPeriod);

        // #endregion assertions.

        // #endregion update management.
    }

    // #endregion test updateVaultInfo.

    // #region test rebalance.

    function testRebalanceOnlyWhitelistedVault() public {
        address vault =
            vm.addr(uint256(keccak256(abi.encode("Meta Vault"))));
        address executor =
            vm.addr(uint256(keccak256(abi.encode("Executor"))));

        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisStandardManager.NotWhitelistedVault.selector,
                vault
            )
        );
        vm.prank(executor);

        bytes[] memory rebalancePayloads = new bytes[](0);

        manager.rebalance(vault, rebalancePayloads);
    }

    function testRebalanceNotExecutor() public {
        // #region init management of vault.

        // #region init management.

        uint24 maxDeviation = TEN_PERCENT; // 10%
        uint256 cooldownPeriod = 60; // 60 seconds.
        address executor =
            vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strategy Announcer")))
        );
        uint24 maxSlippagePIPS = TEN_PERCENT;
        ArrakisMetaVaultMock vault;

        {
            // #region create module.

            LpModuleMock module = new LpModuleMock();

            // #endregion create module.

            // #region create vault.

            vault = new ArrakisMetaVaultMock();
            vault.setManager(address(manager));
            vault.setModule(address(module));

            // #endregion create vault.
        }

        // #region create oracle.

        address oracle =
            vm.addr(uint256(keccak256(abi.encode("Oracle"))));

        // #endregion create oracle.

        {
            // #region set params.

            SetupParams memory params = SetupParams({
                vault: address(vault),
                oracle: IOracleWrapper(oracle),
                maxDeviation: maxDeviation,
                cooldownPeriod: cooldownPeriod,
                executor: executor,
                stratAnnouncer: stratAnnouncer,
                maxSlippagePIPS: maxSlippagePIPS
            });

            // #endregion set params.

            // #region call through the factory initManagement.

            vm.prank(factory);
            manager.initManagement(params);

            // #endregion call through the factory initManagement.
        }

        // #endregion init management.

        // #region assertions.

        (
            ,
            uint256 actualCooldownPeriod,
            IOracleWrapper actualOracle,
            uint24 actualMaxDeviation,
            address actualExecutor,
            address actualStratAnnouncer,
            uint24 actualMaxSlippagePIPS,
            uint24 actualManagerFeePIPS
        ) = manager.vaultInfo(address(vault));

        assertEq(address(actualOracle), oracle);
        assertEq(actualMaxDeviation, maxDeviation);
        assertEq(actualCooldownPeriod, cooldownPeriod);
        assertEq(actualExecutor, executor);
        assertEq(actualStratAnnouncer, stratAnnouncer);
        assertEq(actualMaxSlippagePIPS, maxSlippagePIPS);
        assertEq(actualManagerFeePIPS, defaultFeePIPS);

        // #endregion assertions.

        // #endregion init management of vault.

        address notExecutor =
            vm.addr(uint256(keccak256(abi.encode("Not Executor"))));

        vm.expectRevert(IArrakisStandardManager.NotExecutor.selector);
        vm.prank(notExecutor);

        bytes[] memory rebalancePayloads = new bytes[](0);

        manager.rebalance(address(vault), rebalancePayloads);
    }

    function testRebalanceSetManagerFeePIPS() public {
        // #region init management of vault.

        // #region init management.

        uint24 maxDeviation = TEN_PERCENT; // 10%
        uint256 cooldownPeriod = 60; // 60 seconds.
        address executor =
            vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strategy Announcer")))
        );
        uint24 maxSlippagePIPS = TEN_PERCENT;
        ArrakisMetaVaultMock vault;

        {
            // #region create module.

            LpModuleMock module = new LpModuleMock();
            module.setToken0AndToken1(USDC, NATIVE_COIN);
            deal(USDC, address(module), 2000e6);
            deal(address(module), 1 ether);

            // #endregion create module.

            // #region create vault.

            vault = new ArrakisMetaVaultMock();
            vault.setManager(address(manager));
            vault.setModule(address(module));
            vault.setTokenOAndToken1(USDC, NATIVE_COIN);

            // #endregion create vault.
        }

        // #region create oracle.

        address oracle = address(new OracleMock());

        // #endregion create oracle.

        {
            // #region set params.

            SetupParams memory params = SetupParams({
                vault: address(vault),
                oracle: IOracleWrapper(oracle),
                maxDeviation: maxDeviation,
                cooldownPeriod: cooldownPeriod,
                executor: executor,
                stratAnnouncer: stratAnnouncer,
                maxSlippagePIPS: maxSlippagePIPS
            });

            // #endregion set params.

            // #region call through the factory initManagement.

            vm.prank(factory);
            manager.initManagement(params);

            // #endregion call through the factory initManagement.
        }

        // #endregion init management.

        // #region assertions.

        (
            ,
            uint256 actualCooldownPeriod,
            IOracleWrapper actualOracle,
            uint24 actualMaxDeviation,
            address actualExecutor,
            address actualStratAnnouncer,
            uint24 actualMaxSlippagePIPS,
            uint24 actualManagerFeePIPS
        ) = manager.vaultInfo(address(vault));

        assertEq(address(actualOracle), oracle);
        assertEq(actualMaxDeviation, maxDeviation);
        assertEq(actualCooldownPeriod, cooldownPeriod);
        assertEq(actualExecutor, executor);
        assertEq(actualStratAnnouncer, stratAnnouncer);
        assertEq(actualMaxSlippagePIPS, maxSlippagePIPS);
        assertEq(actualManagerFeePIPS, defaultFeePIPS);

        // #endregion assertions.

        // #endregion init management of vault.

        bytes[] memory rebalancePayloads = new bytes[](1);
        rebalancePayloads[0] = abi.encodeWithSelector(
            LpModuleMock.setManagerFeePIPS.selector, 10_000
        );

        vm.prank(executor);
        vm.expectRevert(
            IArrakisStandardManager
                .SetManagerFeeCallNotAllowed
                .selector
        );

        manager.rebalance(address(vault), rebalancePayloads);
    }

    function testRebalanceCallFailed() public {
        // #region init management of vault.

        // #region init management.

        uint24 maxDeviation = TEN_PERCENT; // 10%
        uint256 cooldownPeriod = 60; // 60 seconds.
        address executor =
            vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strategy Announcer")))
        );
        uint24 maxSlippagePIPS = TEN_PERCENT;
        ArrakisMetaVaultMock vault;

        {
            // #region create module.

            LpModuleMock module = new LpModuleMock();
            module.setToken0AndToken1(USDC, NATIVE_COIN);
            deal(USDC, address(module), 2000e6);
            deal(address(module), 1 ether);

            // #endregion create module.

            // #region create vault.

            vault = new ArrakisMetaVaultMock();
            vault.setManager(address(manager));
            vault.setModule(address(module));
            vault.setTokenOAndToken1(USDC, NATIVE_COIN);

            // #endregion create vault.
        }

        // #region create oracle.

        address oracle = address(new OracleMock());

        // #endregion create oracle.

        {
            // #region set params.

            SetupParams memory params = SetupParams({
                vault: address(vault),
                oracle: IOracleWrapper(oracle),
                maxDeviation: maxDeviation,
                cooldownPeriod: cooldownPeriod,
                executor: executor,
                stratAnnouncer: stratAnnouncer,
                maxSlippagePIPS: maxSlippagePIPS
            });

            // #endregion set params.

            // #region call through the factory initManagement.

            vm.prank(factory);
            manager.initManagement(params);

            // #endregion call through the factory initManagement.
        }

        // #endregion init management.

        // #region assertions.

        (
            ,
            uint256 actualCooldownPeriod,
            IOracleWrapper actualOracle,
            uint24 actualMaxDeviation,
            address actualExecutor,
            address actualStratAnnouncer,
            uint24 actualMaxSlippagePIPS,
            uint24 actualManagerFeePIPS
        ) = manager.vaultInfo(address(vault));

        assertEq(address(actualOracle), oracle);
        assertEq(actualMaxDeviation, maxDeviation);
        assertEq(actualCooldownPeriod, cooldownPeriod);
        assertEq(actualExecutor, executor);
        assertEq(actualStratAnnouncer, stratAnnouncer);
        assertEq(actualMaxSlippagePIPS, maxSlippagePIPS);
        assertEq(actualManagerFeePIPS, defaultFeePIPS);

        // #endregion assertions.

        // #endregion init management of vault.

        bytes[] memory rebalancePayloads = new bytes[](1);
        rebalancePayloads[0] = abi.encodeWithSelector(
            LpModuleMock.thirdRebalanceFunction.selector
        );

        vm.prank(executor);
        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisStandardManager.CallFailed.selector,
                rebalancePayloads[0]
            )
        );

        manager.rebalance(address(vault), rebalancePayloads);
    }

    function testRebalanceOverMaxSlippage() public {
        // #region init management of vault.

        // #region init management.

        uint24 maxDeviation = TEN_PERCENT; // 10%
        uint256 cooldownPeriod = 60; // 60 seconds.
        address executor =
            vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strategy Announcer")))
        );
        uint24 maxSlippagePIPS = TEN_PERCENT;
        ArrakisMetaVaultMock vault;

        {
            // #region create module.

            address depositor =
                vm.addr(uint256(keccak256(abi.encode("Depositor"))));

            LpModuleMock module = new LpModuleMock();
            module.setToken0AndToken1(USDC, WETH);
            module.setDepositor(depositor);
            deal(USDC, address(module), 2000e6);
            deal(WETH, address(module), 1 ether);

            deal(WETH, depositor, 0.5 ether);

            vm.prank(depositor);
            IERC20(WETH).approve(address(module), 0.5 ether);

            // #endregion create module.

            // #region create vault.

            vault = new ArrakisMetaVaultMock();
            vault.setManager(address(manager));
            vault.setModule(address(module));
            vault.setTokenOAndToken1(USDC, WETH);

            // #endregion create vault.
        }

        // #region create oracle.

        address oracle = address(new OracleMock());

        // #endregion create oracle.

        {
            // #region set params.

            SetupParams memory params = SetupParams({
                vault: address(vault),
                oracle: IOracleWrapper(oracle),
                maxDeviation: maxDeviation,
                cooldownPeriod: cooldownPeriod,
                executor: executor,
                stratAnnouncer: stratAnnouncer,
                maxSlippagePIPS: maxSlippagePIPS
            });

            // #endregion set params.

            // #region call through the factory initManagement.

            vm.prank(factory);
            manager.initManagement(params);

            // #endregion call through the factory initManagement.
        }

        // #endregion init management.

        // #region assertions.

        (
            ,
            uint256 actualCooldownPeriod,
            IOracleWrapper actualOracle,
            uint24 actualMaxDeviation,
            address actualExecutor,
            address actualStratAnnouncer,
            uint24 actualMaxSlippagePIPS,
            uint24 actualManagerFeePIPS
        ) = manager.vaultInfo(address(vault));

        assertEq(address(actualOracle), oracle);
        assertEq(actualMaxDeviation, maxDeviation);
        assertEq(actualCooldownPeriod, cooldownPeriod);
        assertEq(actualExecutor, executor);
        assertEq(actualStratAnnouncer, stratAnnouncer);
        assertEq(actualMaxSlippagePIPS, maxSlippagePIPS);
        assertEq(actualManagerFeePIPS, defaultFeePIPS);

        // #endregion assertions.

        // #endregion init management of vault.

        bytes[] memory rebalancePayloads = new bytes[](2);
        rebalancePayloads[0] = abi.encodeWithSelector(
            LpModuleMock.firstRebalanceFunction.selector, 0.0005 ether
        );
        rebalancePayloads[1] = abi.encodeWithSelector(
            LpModuleMock.secondRebalanceFunction.selector
        );

        vm.prank(executor);
        vm.expectRevert(
            IArrakisStandardManager.OverMaxSlippage.selector
        );

        manager.rebalance(address(vault), rebalancePayloads);
    }

    function testRebalance() public {
        // #region init management of vault.

        // #region init management.

        uint24 maxDeviation = TEN_PERCENT; // 10%
        uint256 cooldownPeriod = 60; // 60 seconds.
        address executor =
            vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strategy Announcer")))
        );
        uint24 maxSlippagePIPS = TEN_PERCENT;
        ArrakisMetaVaultMock vault;

        {
            // #region create module.

            address depositor =
                vm.addr(uint256(keccak256(abi.encode("Depositor"))));

            LpModuleMock module = new LpModuleMock();
            module.setToken0AndToken1(USDC, WETH);
            module.setDepositor(depositor);
            deal(USDC, address(module), 2000e6);
            deal(WETH, address(module), 1 ether);

            deal(WETH, depositor, 0.5 ether);

            vm.prank(depositor);
            IERC20(WETH).approve(address(module), 0.5 ether);

            // #endregion create module.

            // #region create vault.

            vault = new ArrakisMetaVaultMock();
            vault.setManager(address(manager));
            vault.setModule(address(module));
            vault.setTokenOAndToken1(USDC, WETH);

            // #endregion create vault.
        }

        // #region create oracle.

        address oracle = address(new OracleMock());

        // #endregion create oracle.

        {
            // #region set params.

            SetupParams memory params = SetupParams({
                vault: address(vault),
                oracle: IOracleWrapper(oracle),
                maxDeviation: maxDeviation,
                cooldownPeriod: cooldownPeriod,
                executor: executor,
                stratAnnouncer: stratAnnouncer,
                maxSlippagePIPS: maxSlippagePIPS
            });

            // #endregion set params.

            // #region call through the factory initManagement.

            vm.prank(factory);
            manager.initManagement(params);

            // #endregion call through the factory initManagement.
        }

        // #endregion init management.

        // #region assertions.

        (
            ,
            uint256 actualCooldownPeriod,
            IOracleWrapper actualOracle,
            uint24 actualMaxDeviation,
            address actualExecutor,
            address actualStratAnnouncer,
            uint24 actualMaxSlippagePIPS,
            uint24 actualManagerFeePIPS
        ) = manager.vaultInfo(address(vault));

        assertEq(address(actualOracle), oracle);
        assertEq(actualMaxDeviation, maxDeviation);
        assertEq(actualCooldownPeriod, cooldownPeriod);
        assertEq(actualExecutor, executor);
        assertEq(actualStratAnnouncer, stratAnnouncer);
        assertEq(actualMaxSlippagePIPS, maxSlippagePIPS);
        assertEq(actualManagerFeePIPS, defaultFeePIPS);

        // #endregion assertions.

        // #endregion init management of vault.

        bytes[] memory rebalancePayloads = new bytes[](1);
        rebalancePayloads[0] = abi.encodeWithSelector(
            LpModuleMock.firstRebalanceFunction.selector, 0.0005 ether
        );

        vm.prank(executor);

        manager.rebalance(address(vault), rebalancePayloads);
    }

    function testRebalanceTimeNotPassed() public {
        // #region init management of vault.

        // #region init management.

        uint24 maxDeviation = TEN_PERCENT; // 10%
        uint256 cooldownPeriod = 60; // 60 seconds.
        address executor =
            vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strategy Announcer")))
        );
        uint24 maxSlippagePIPS = TEN_PERCENT;
        ArrakisMetaVaultMock vault;

        {
            // #region create module.

            address depositor =
                vm.addr(uint256(keccak256(abi.encode("Depositor"))));

            LpModuleMock module = new LpModuleMock();
            module.setToken0AndToken1(USDC, WETH);
            module.setDepositor(depositor);
            deal(USDC, address(module), 2000e6);
            deal(WETH, address(module), 1 ether);

            deal(WETH, depositor, 0.5 ether);

            vm.prank(depositor);
            IERC20(WETH).approve(address(module), 0.5 ether);

            // #endregion create module.

            // #region create vault.

            vault = new ArrakisMetaVaultMock();
            vault.setManager(address(manager));
            vault.setModule(address(module));
            vault.setTokenOAndToken1(USDC, WETH);

            // #endregion create vault.
        }

        // #region create oracle.

        address oracle = address(new OracleMock());

        // #endregion create oracle.

        {
            // #region set params.

            SetupParams memory params = SetupParams({
                vault: address(vault),
                oracle: IOracleWrapper(oracle),
                maxDeviation: maxDeviation,
                cooldownPeriod: cooldownPeriod,
                executor: executor,
                stratAnnouncer: stratAnnouncer,
                maxSlippagePIPS: maxSlippagePIPS
            });

            // #endregion set params.

            // #region call through the factory initManagement.

            vm.prank(factory);
            manager.initManagement(params);

            // #endregion call through the factory initManagement.
        }

        // #endregion init management.

        // #region assertions.

        (
            ,
            uint256 actualCooldownPeriod,
            IOracleWrapper actualOracle,
            uint24 actualMaxDeviation,
            address actualExecutor,
            address actualStratAnnouncer,
            uint24 actualMaxSlippagePIPS,
            uint24 actualManagerFeePIPS
        ) = manager.vaultInfo(address(vault));

        assertEq(address(actualOracle), oracle);
        assertEq(actualMaxDeviation, maxDeviation);
        assertEq(actualCooldownPeriod, cooldownPeriod);
        assertEq(actualExecutor, executor);
        assertEq(actualStratAnnouncer, stratAnnouncer);
        assertEq(actualMaxSlippagePIPS, maxSlippagePIPS);
        assertEq(actualManagerFeePIPS, defaultFeePIPS);

        // #endregion assertions.

        // #endregion init management of vault.

        bytes[] memory rebalancePayloads = new bytes[](1);
        rebalancePayloads[0] = abi.encodeWithSelector(
            LpModuleMock.firstRebalanceFunction.selector, 0.0005 ether
        );

        vm.startPrank(executor);

        manager.rebalance(address(vault), rebalancePayloads);

        vm.expectRevert(
            IArrakisStandardManager.TimeNotPassed.selector
        );

        manager.rebalance(address(vault), rebalancePayloads);

        vm.stopPrank();
    }

    // #endregion test rebalance.

    // #region test announceStrategy.

    function testAnnouceStrategyNotWhitelistedVault() public {
        address vault =
            vm.addr(uint256(keccak256(abi.encode("Vault"))));

        string memory strategy = "HOT";

        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisStandardManager.NotWhitelistedVault.selector,
                vault
            )
        );
        manager.announceStrategy(vault, strategy);
    }

    function testAnnouceStrategyOnlyStratAnnouncer() public {
        // #region init management.

        uint24 maxDeviation = TEN_PERCENT; // 10%
        uint256 cooldownPeriod = 60; // 60 seconds.
        address executor =
            vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strategy Announcer")))
        );
        uint24 maxSlippagePIPS = TEN_PERCENT;
        ArrakisMetaVaultMock vault;

        {
            // #region create module.

            LpModuleMock module = new LpModuleMock();

            // #endregion create module.

            // #region create vault.

            vault = new ArrakisMetaVaultMock();
            vault.setManager(address(manager));
            vault.setModule(address(module));

            // #endregion create vault.
        }

        // #region create oracle.

        address oracle =
            vm.addr(uint256(keccak256(abi.encode("Oracle"))));

        // #endregion create oracle.

        {
            // #region set params.

            SetupParams memory params = SetupParams({
                vault: address(vault),
                oracle: IOracleWrapper(oracle),
                maxDeviation: maxDeviation,
                cooldownPeriod: cooldownPeriod,
                executor: executor,
                stratAnnouncer: stratAnnouncer,
                maxSlippagePIPS: maxSlippagePIPS
            });

            // #endregion set params.

            // #region call through the factory initManagement.

            vm.prank(factory);
            manager.initManagement(params);

            // #endregion call through the factory initManagement.
        }

        // #endregion init management.

        string memory strategy = "HOT";

        vm.expectRevert(
            IArrakisStandardManager.OnlyStratAnnouncer.selector
        );
        manager.announceStrategy(address(vault), strategy);
    }

    function testAnnouceStrategy() public {
        // #region init management.

        uint24 maxDeviation = TEN_PERCENT; // 10%
        uint256 cooldownPeriod = 60; // 60 seconds.
        address executor =
            vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strategy Announcer")))
        );
        uint24 maxSlippagePIPS = TEN_PERCENT;
        ArrakisMetaVaultMock vault;

        {
            // #region create module.

            LpModuleMock module = new LpModuleMock();

            // #endregion create module.

            // #region create vault.

            vault = new ArrakisMetaVaultMock();
            vault.setManager(address(manager));
            vault.setModule(address(module));

            // #endregion create vault.
        }

        // #region create oracle.

        address oracle =
            vm.addr(uint256(keccak256(abi.encode("Oracle"))));

        // #endregion create oracle.

        {
            // #region set params.

            SetupParams memory params = SetupParams({
                vault: address(vault),
                oracle: IOracleWrapper(oracle),
                maxDeviation: maxDeviation,
                cooldownPeriod: cooldownPeriod,
                executor: executor,
                stratAnnouncer: stratAnnouncer,
                maxSlippagePIPS: maxSlippagePIPS
            });

            // #endregion set params.

            // #region call through the factory initManagement.

            vm.prank(factory);
            manager.initManagement(params);

            // #endregion call through the factory initManagement.
        }

        // #endregion init management.

        string memory strategy = "HOT";

        vm.expectEmit();
        emit LogStrategyAnnouncement(address(vault), strategy);

        vm.prank(stratAnnouncer);
        manager.announceStrategy(address(vault), strategy);
    }

    // #endregion test annouceStrategy.

    // #region test initializedVaults.

    function testInitializedVaultsStartIndexLtEndIndex() public {
        uint256 startIndex = 10;
        uint256 endIndex = 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisStandardManager.StartIndexLtEndIndex.selector,
                startIndex,
                endIndex
            )
        );

        manager.initializedVaults(startIndex, endIndex);
    }

    function testInitializedVaultsEndIndexGtNbOfVaults() public {
        uint256 startIndex = 0;
        uint256 endIndex = 10;
        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisStandardManager.EndIndexGtNbOfVaults.selector,
                endIndex,
                0
            )
        );

        manager.initializedVaults(startIndex, endIndex);
    }

    function testInitializedVaults() public {
        // #region init management.

        uint24 maxDeviation = TEN_PERCENT; // 10%
        uint256 cooldownPeriod = 60; // 60 seconds.
        address executor =
            vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strategy Announcer")))
        );
        uint24 maxSlippagePIPS = TEN_PERCENT;
        ArrakisMetaVaultMock vault;

        {
            // #region create module.

            LpModuleMock module = new LpModuleMock();

            // #endregion create module.

            // #region create vault.

            vault = new ArrakisMetaVaultMock();
            vault.setManager(address(manager));
            vault.setModule(address(module));

            // #endregion create vault.
        }

        // #region create oracle.

        address oracle =
            vm.addr(uint256(keccak256(abi.encode("Oracle"))));

        // #endregion create oracle.

        {
            // #region set params.

            SetupParams memory params = SetupParams({
                vault: address(vault),
                oracle: IOracleWrapper(oracle),
                maxDeviation: maxDeviation,
                cooldownPeriod: cooldownPeriod,
                executor: executor,
                stratAnnouncer: stratAnnouncer,
                maxSlippagePIPS: maxSlippagePIPS
            });

            // #endregion set params.

            // #region call through the factory initManagement.

            vm.prank(factory);
            manager.initManagement(params);

            // #endregion call through the factory initManagement.
        }

        // #endregion init management.

        // #region assertions.

        (
            ,
            uint256 actualCooldownPeriod,
            IOracleWrapper actualOracle,
            uint24 actualMaxDeviation,
            address actualExecutor,
            address actualStratAnnouncer,
            uint24 actualMaxSlippagePIPS,
            uint24 actualManagerFeePIPS
        ) = manager.vaultInfo(address(vault));

        assertEq(address(actualOracle), oracle);
        assertEq(actualMaxDeviation, maxDeviation);
        assertEq(actualCooldownPeriod, cooldownPeriod);
        assertEq(actualExecutor, executor);
        assertEq(actualStratAnnouncer, stratAnnouncer);
        assertEq(actualMaxSlippagePIPS, maxSlippagePIPS);
        assertEq(actualManagerFeePIPS, defaultFeePIPS);

        // #endregion assertions.

        uint256 startIndex = 0;
        uint256 endIndex = 1;

        address[] memory vaults =
            manager.initializedVaults(startIndex, endIndex);

        assertEq(vaults.length, 1);
        assertEq(vaults[0], address(vault));
    }

    // #endregion test initializedVaults.

    // #region test isManaged.

    function testIsManaged() public {
        // #region init management.

        uint24 maxDeviation = TEN_PERCENT; // 10%
        uint256 cooldownPeriod = 60; // 60 seconds.
        address executor =
            vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strategy Announcer")))
        );
        uint24 maxSlippagePIPS = TEN_PERCENT;
        ArrakisMetaVaultMock vault;

        {
            // #region create module.

            LpModuleMock module = new LpModuleMock();

            // #endregion create module.

            // #region create vault.

            vault = new ArrakisMetaVaultMock();
            vault.setManager(address(manager));
            vault.setModule(address(module));

            // #endregion create vault.
        }

        // #region create oracle.

        address oracle =
            vm.addr(uint256(keccak256(abi.encode("Oracle"))));

        // #endregion create oracle.

        {
            // #region set params.

            SetupParams memory params = SetupParams({
                vault: address(vault),
                oracle: IOracleWrapper(oracle),
                maxDeviation: maxDeviation,
                cooldownPeriod: cooldownPeriod,
                executor: executor,
                stratAnnouncer: stratAnnouncer,
                maxSlippagePIPS: maxSlippagePIPS
            });

            // #endregion set params.

            // #region call through the factory initManagement.

            vm.prank(factory);
            manager.initManagement(params);

            // #endregion call through the factory initManagement.
        }

        // #endregion init management.

        // #region assertions.

        (
            ,
            uint256 actualCooldownPeriod,
            IOracleWrapper actualOracle,
            uint24 actualMaxDeviation,
            address actualExecutor,
            address actualStratAnnouncer,
            uint24 actualMaxSlippagePIPS,
            uint24 actualManagerFeePIPS
        ) = manager.vaultInfo(address(vault));

        assertEq(address(actualOracle), oracle);
        assertEq(actualMaxDeviation, maxDeviation);
        assertEq(actualCooldownPeriod, cooldownPeriod);
        assertEq(actualExecutor, executor);
        assertEq(actualStratAnnouncer, stratAnnouncer);
        assertEq(actualMaxSlippagePIPS, maxSlippagePIPS);
        assertEq(actualManagerFeePIPS, defaultFeePIPS);

        // #endregion assertions.

        assert(manager.isManaged(address(vault)));
    }

    // #endregion test isManaged.

    // #region test numInitializedVaults.

    function testNumInitializedVaults() public {
        // #region init management.

        uint24 maxDeviation = TEN_PERCENT; // 10%
        uint256 cooldownPeriod = 60; // 60 seconds.
        address executor =
            vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strategy Announcer")))
        );
        uint24 maxSlippagePIPS = TEN_PERCENT;
        ArrakisMetaVaultMock vault;

        {
            // #region create module.

            LpModuleMock module = new LpModuleMock();

            // #endregion create module.

            // #region create vault.

            vault = new ArrakisMetaVaultMock();
            vault.setManager(address(manager));
            vault.setModule(address(module));

            // #endregion create vault.
        }

        // #region create oracle.

        address oracle =
            vm.addr(uint256(keccak256(abi.encode("Oracle"))));

        // #endregion create oracle.

        {
            // #region set params.

            SetupParams memory params = SetupParams({
                vault: address(vault),
                oracle: IOracleWrapper(oracle),
                maxDeviation: maxDeviation,
                cooldownPeriod: cooldownPeriod,
                executor: executor,
                stratAnnouncer: stratAnnouncer,
                maxSlippagePIPS: maxSlippagePIPS
            });

            // #endregion set params.

            // #region call through the factory initManagement.

            vm.prank(factory);
            manager.initManagement(params);

            // #endregion call through the factory initManagement.
        }

        // #endregion init management.

        // #region assertions.

        (
            ,
            uint256 actualCooldownPeriod,
            IOracleWrapper actualOracle,
            uint24 actualMaxDeviation,
            address actualExecutor,
            address actualStratAnnouncer,
            uint24 actualMaxSlippagePIPS,
            uint24 actualManagerFeePIPS
        ) = manager.vaultInfo(address(vault));

        assertEq(address(actualOracle), oracle);
        assertEq(actualMaxDeviation, maxDeviation);
        assertEq(actualCooldownPeriod, cooldownPeriod);
        assertEq(actualExecutor, executor);
        assertEq(actualStratAnnouncer, stratAnnouncer);
        assertEq(actualMaxSlippagePIPS, maxSlippagePIPS);
        assertEq(actualManagerFeePIPS, defaultFeePIPS);

        // #endregion assertions.

        assertEq(manager.numInitializedVaults(), 1);
    }

    // #endregion test numInitializedVaults.

    // #region test getInitManagementSelector.

    function testGetInitManagementSelector() public {
        assertEq(
            manager.getInitManagementSelector(),
            IArrakisStandardManager.initManagement.selector
        );
    }

    // #endregion test getInitManagementSelector.
}
