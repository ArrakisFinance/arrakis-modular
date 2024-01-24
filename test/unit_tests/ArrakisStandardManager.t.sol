// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";

import {TestWrapper} from "../utils/TestWrapper.sol";

import {ArrakisStandardManager, IArrakisStandardManager} from "../../src/ArrakisStandardManager.sol";
import {ArrakisMetaVaultFactory} from "../../src/ArrakisMetaVaultFactory.sol";
import {IArrakisMetaVault} from "../../src/interfaces/IArrakisMetaVault.sol";
import {PIPS, TEN_PERCENT, NATIVE_COIN, WEEK} from "../../src/constants/CArrakis.sol";
import {SetupParams, FeeIncrease} from "../../src/structs/SManager.sol";

// #region solady.

import {Ownable} from "@solady/contracts/auth/Ownable.sol";

// #endregion solady

// #region openzeppelin.

import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// #endregion openzeppelin.

// #region mock contracts.

import {LpModuleMock} from "../mocks/LpModuleMock.sol";
import {OracleMock, IOracleWrapper} from "../mocks/OracleMock.sol";

// #endregion mock contracts.

contract ArrakisStandardManagerTest is TestWrapper {
    // #region constant properties.

    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    /// @dev native token ether in our case.
    /// follow uniswap v4 standard
    /// https://github.com/Uniswap/v4-core/blob/8109ec3c2f9db321ba48fff44ed429e6c1bd3eb3/src/types/Currency.sol#L37
    uint8 public constant nativeTokenDecimals = 18;
    uint256 public constant defaultFeePIPS = TEN_PERCENT;

    // #endregion constant properties.

    // #region public properties.

    ArrakisStandardManager public manager;
    address public managerOwner;
    ArrakisMetaVaultFactory public factory;
    address public factoryOwner;
    address public defaultReceiver;
    LpModuleMock public module;
    OracleMock public oracle;

    address public wethReceiver;
    address public usdcReceiver;

    /// @dev public vault.
    IArrakisMetaVault public vault;

    // #endregion public properties.

    function setUp() public {
        managerOwner = vm.addr(uint256(keccak256(abi.encode("Manager Owner"))));
        factoryOwner = vm.addr(uint256(keccak256(abi.encode("Factory Owner"))));
        defaultReceiver = vm.addr(
            uint256(keccak256(abi.encode("Default Receiver")))
        );
        wethReceiver = vm.addr(uint256(keccak256(abi.encode("WETH Receiver"))));
        usdcReceiver = vm.addr(uint256(keccak256(abi.encode("USDC Receiver"))));

        manager = new ArrakisStandardManager(
            managerOwner,
            defaultReceiver,
            defaultFeePIPS,
            NATIVE_COIN,
            nativeTokenDecimals
        );

        factory = new ArrakisMetaVaultFactory(factoryOwner);

        // #region create module.

        module = new LpModuleMock(USDC, WETH, address(manager));

        // #endregion create module.

        // #region create oracle.

        oracle = new OracleMock();

        // #endregion create oracle.

        // #region create a public vault.

        bytes32 salt = keccak256(abi.encode("Test Public Vault"));

        vault = IArrakisMetaVault(
            factory.deployPublicVault(
                salt,
                USDC,
                WETH,
                address(this),
                address(module)
            )
        );

        // #endregion create a public vault.
    }

    // #region test constructor.

    function testConstructorOwnerAddressZero() public {
        vm.expectRevert(IArrakisStandardManager.AddressZero.selector);

        manager = new ArrakisStandardManager(
            address(0),
            defaultReceiver,
            defaultFeePIPS,
            NATIVE_COIN,
            nativeTokenDecimals
        );
    }

    function testConstructorDefaultReceiverAddressZero() public {
        vm.expectRevert(IArrakisStandardManager.AddressZero.selector);

        manager = new ArrakisStandardManager(
            managerOwner,
            address(0),
            defaultFeePIPS,
            NATIVE_COIN,
            nativeTokenDecimals
        );
    }

    function testConstructorNativeCoinAddressZero() public {
        vm.expectRevert(IArrakisStandardManager.AddressZero.selector);

        manager = new ArrakisStandardManager(
            managerOwner,
            defaultReceiver,
            defaultFeePIPS,
            address(0),
            nativeTokenDecimals
        );
    }

    function testConstructorNativeTokenDecimalZero() public {
        vm.expectRevert(
            IArrakisStandardManager.NativeTokenDecimalsZero.selector
        );

        manager = new ArrakisStandardManager(
            managerOwner,
            defaultReceiver,
            defaultFeePIPS,
            NATIVE_COIN,
            0
        );
    }

    // #endregion test constructor.

    // #region test pause/unpause.

    function testPausedOnlyOwner() public {
        address caller = vm.addr(111);

        vm.prank(caller);
        vm.expectRevert(Ownable.Unauthorized.selector);

        manager.pause();
    }

    function testPause() public {
        assertEq(manager.paused(), false);

        vm.prank(managerOwner);
        manager.pause();

        assertEq(manager.paused(), true);
    }

    function testUnPauseOnlyOwner() public {
        vm.prank(managerOwner);
        manager.pause();
        address caller = vm.addr(111);

        vm.prank(caller);
        vm.expectRevert(Ownable.Unauthorized.selector);

        manager.unpause();
    }

    function testUnPauseNotPaused() public {
        assertEq(manager.paused(), false);

        vm.prank(managerOwner);
        vm.expectRevert(Pausable.ExpectedPause.selector);
        manager.unpause();
    }

    function testUnPause() public {
        assertEq(manager.paused(), false);

        vm.prank(managerOwner);
        manager.pause();

        assertEq(manager.paused(), true);

        vm.prank(managerOwner);
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
        vm.prank(managerOwner);
        vm.expectRevert(IArrakisStandardManager.AddressZero.selector);

        manager.setDefaultReceiver(address(0));
    }

    function testSetDefaultReceiver() public {
        address newDefaultReceiver = vm.addr(
            uint256(keccak256(abi.encode("New Default Receiver")))
        );

        assertEq(manager.defaultReceiver(), defaultReceiver);

        vm.prank(managerOwner);

        manager.setDefaultReceiver(newDefaultReceiver);

        assertEq(manager.defaultReceiver(), newDefaultReceiver);
    }

    // #endregion test setDefaultReceiver.

    // #region test setReceiverByToken.

    function testSetReceiverByTokenOnlyOwner() public {
        vm.expectRevert(Ownable.Unauthorized.selector);

        manager.setReceiverByToken(address(vault), true, usdcReceiver);
    }

    function testSetReceiverByTokenOnlyWhitelisted() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisStandardManager.NotWhitelistedVault.selector,
                address(vault)
            )
        );

        vm.prank(managerOwner);

        manager.setReceiverByToken(address(vault), true, usdcReceiver);
    }

    function testSetReceiverAddressZero() public {
        // #region setManager.

        vault.setManager(address(manager));

        // #endregion setManager.

        // #region whitelist vault.

        uint24 maxDeviation = PIPS / 100; // 1% max deviation.
        uint256 cooldownPeriod = 60;
        address executor = vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strat Announcer")))
        );
        uint24 maxSlippagePIPS = PIPS / 100; // 1% max slippage.

        manager.initManagement(
            SetupParams({
                vault: address(vault),
                oracle: oracle,
                maxDeviation: maxDeviation,
                cooldownPeriod: cooldownPeriod,
                executor: executor,
                stratAnnouncer: stratAnnouncer,
                maxSlippagePIPS: maxSlippagePIPS
            })
        );

        // #endregion whitelist vault.

        vm.prank(managerOwner);
        vm.expectRevert(IArrakisStandardManager.AddressZero.selector);
        manager.setReceiverByToken(address(vault), true, address(0));
    }

    function testSetReceiverByToken() public {
        // #region setManager.

        vault.setManager(address(manager));

        // #endregion setManager.

        // #region whitelist vault.

        uint24 maxDeviation = PIPS / 100; // 1% max deviation.
        uint256 cooldownPeriod = 60;
        address executor = vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strat Announcer")))
        );
        uint24 maxSlippagePIPS = PIPS / 100; // 1% max slippage.

        manager.initManagement(
            SetupParams({
                vault: address(vault),
                oracle: oracle,
                maxDeviation: maxDeviation,
                cooldownPeriod: cooldownPeriod,
                executor: executor,
                stratAnnouncer: stratAnnouncer,
                maxSlippagePIPS: maxSlippagePIPS
            })
        );

        // #endregion whitelist vault.

        assertEq(manager.receiversByToken(USDC), address(0));

        vm.prank(managerOwner);

        manager.setReceiverByToken(address(vault), true, usdcReceiver);

        assertEq(manager.receiversByToken(USDC), usdcReceiver);
    }

    // #endregion test setReceiverByToken.

    // #region test decreaseManagerFeePIPS.

    function testDecreaseManagerFeePIPSOnlyOwner() public {
        // #region setManager.

        vault.setManager(address(manager));

        // #endregion setManager.

        // #region whitelist vault.

        uint24 maxDeviation = PIPS / 100; // 1% max deviation.
        uint256 cooldownPeriod = 60;
        address executor = vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strat Announcer")))
        );
        uint24 maxSlippagePIPS = PIPS / 100; // 1% max slippage.

        manager.initManagement(
            SetupParams({
                vault: address(vault),
                oracle: oracle,
                maxDeviation: maxDeviation,
                cooldownPeriod: cooldownPeriod,
                executor: executor,
                stratAnnouncer: stratAnnouncer,
                maxSlippagePIPS: maxSlippagePIPS
            })
        );

        // #endregion whitelist vault.

        assertEq(manager.receiversByToken(USDC), address(0));

        vm.prank(managerOwner);

        manager.setReceiverByToken(address(vault), true, usdcReceiver);

        assertEq(manager.receiversByToken(USDC), usdcReceiver);

        vm.expectRevert(Ownable.Unauthorized.selector);

        manager.decreaseManagerFeePIPS(
            address(vault),
            SafeCast.toUint24(defaultFeePIPS / 2)
        );
    }

    function testDecreaseManagerFeePIPSNotWhitelisted() public {
        // #region setManager.

        vault.setManager(address(manager));

        // #endregion setManager.

        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisStandardManager.NotWhitelistedVault.selector,
                address(vault)
            )
        );
        vm.prank(managerOwner);

        manager.decreaseManagerFeePIPS(
            address(vault),
            SafeCast.toUint24(defaultFeePIPS / 2)
        );
    }

    function testDecreaseManagerNotFeeDecrease() public {
        // #region setManager.

        vault.setManager(address(manager));

        // #endregion setManager.

        // #region whitelist vault.

        uint24 maxDeviation = PIPS / 100; // 1% max deviation.
        uint256 cooldownPeriod = 60;
        address executor = vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strat Announcer")))
        );
        uint24 maxSlippagePIPS = PIPS / 100; // 1% max slippage.

        manager.initManagement(
            SetupParams({
                vault: address(vault),
                oracle: oracle,
                maxDeviation: maxDeviation,
                cooldownPeriod: cooldownPeriod,
                executor: executor,
                stratAnnouncer: stratAnnouncer,
                maxSlippagePIPS: maxSlippagePIPS
            })
        );

        // #endregion whitelist vault.

        assertEq(manager.receiversByToken(USDC), address(0));

        vm.prank(managerOwner);

        manager.setReceiverByToken(address(vault), true, usdcReceiver);

        assertEq(manager.receiversByToken(USDC), usdcReceiver);

        vm.expectRevert(IArrakisStandardManager.NotFeeDecrease.selector);
        vm.prank(managerOwner);

        manager.decreaseManagerFeePIPS(
            address(vault),
            SafeCast.toUint24(defaultFeePIPS * 2)
        );
    }

    function testDecreaseManager() public {
        // #region setManager.

        vault.setManager(address(manager));

        // #endregion setManager.

        // #region whitelist vault.

        uint24 maxDeviation = PIPS / 100; // 1% max deviation.
        uint256 cooldownPeriod = 60;
        address executor = vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strat Announcer")))
        );
        uint24 maxSlippagePIPS = PIPS / 100; // 1% max slippage.

        manager.initManagement(
            SetupParams({
                vault: address(vault),
                oracle: oracle,
                maxDeviation: maxDeviation,
                cooldownPeriod: cooldownPeriod,
                executor: executor,
                stratAnnouncer: stratAnnouncer,
                maxSlippagePIPS: maxSlippagePIPS
            })
        );

        // #endregion whitelist vault.

        assertEq(manager.receiversByToken(USDC), address(0));

        vm.prank(managerOwner);

        manager.setReceiverByToken(address(vault), true, usdcReceiver);

        assertEq(manager.receiversByToken(USDC), usdcReceiver);

        vm.prank(managerOwner);

        manager.decreaseManagerFeePIPS(
            address(vault),
            SafeCast.toUint24(defaultFeePIPS / 2)
        );
    }

    // #endregion test decreaseManagerFeePIPS.

    // #region test submitIncreaseManagerFeePIPS.

    function testSubmitIncreaseManagerFeePIPSNotOwner() public {
        // #region setManager.

        vault.setManager(address(manager));

        // #endregion setManager.

        // #region whitelist vault.

        uint24 maxDeviation = PIPS / 100; // 1% max deviation.
        uint256 cooldownPeriod = 60;
        address executor = vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strat Announcer")))
        );
        uint24 maxSlippagePIPS = PIPS / 100; // 1% max slippage.

        manager.initManagement(
            SetupParams({
                vault: address(vault),
                oracle: oracle,
                maxDeviation: maxDeviation,
                cooldownPeriod: cooldownPeriod,
                executor: executor,
                stratAnnouncer: stratAnnouncer,
                maxSlippagePIPS: maxSlippagePIPS
            })
        );

        // #endregion whitelist vault.

        assertEq(manager.receiversByToken(USDC), address(0));

        vm.prank(managerOwner);

        manager.setReceiverByToken(address(vault), true, usdcReceiver);

        assertEq(manager.receiversByToken(USDC), usdcReceiver);

        vm.expectRevert(Ownable.Unauthorized.selector);

        manager.submitIncreaseManagerFeePIPS(
            address(vault),
            SafeCast.toUint24(defaultFeePIPS * 2)
        );
    }

    function testSubmitIncreaseManagerFeePIPSNotWhitelisted() public {
        // #region setManager.

        vault.setManager(address(manager));

        // #endregion setManager.

        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisStandardManager.NotWhitelistedVault.selector,
                address(vault)
            )
        );
        vm.prank(managerOwner);

        manager.submitIncreaseManagerFeePIPS(
            address(vault),
            SafeCast.toUint24(defaultFeePIPS / 2)
        );
    }

    function testSubmitIncreaseManagerFeePIPSNotFeeDecrease() public {
        // #region setManager.

        vault.setManager(address(manager));

        // #endregion setManager.

        // #region whitelist vault.

        uint24 maxDeviation = PIPS / 100; // 1% max deviation.
        uint256 cooldownPeriod = 60;
        address executor = vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strat Announcer")))
        );
        uint24 maxSlippagePIPS = PIPS / 100; // 1% max slippage.

        manager.initManagement(
            SetupParams({
                vault: address(vault),
                oracle: oracle,
                maxDeviation: maxDeviation,
                cooldownPeriod: cooldownPeriod,
                executor: executor,
                stratAnnouncer: stratAnnouncer,
                maxSlippagePIPS: maxSlippagePIPS
            })
        );

        // #endregion whitelist vault.

        assertEq(manager.receiversByToken(USDC), address(0));

        vm.prank(managerOwner);

        manager.setReceiverByToken(address(vault), true, usdcReceiver);

        assertEq(manager.receiversByToken(USDC), usdcReceiver);

        vm.expectRevert(IArrakisStandardManager.NotFeeIncrease.selector);
        vm.prank(managerOwner);

        manager.submitIncreaseManagerFeePIPS(
            address(vault),
            SafeCast.toUint24(defaultFeePIPS / 2)
        );
    }

    function testSubmitIncreaseManagerFeePIPSAlreadyPending() public {
        // #region setManager.

        vault.setManager(address(manager));

        // #endregion setManager.

        // #region whitelist vault.

        uint24 maxDeviation = PIPS / 100; // 1% max deviation.
        uint256 cooldownPeriod = 60;
        address executor = vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strat Announcer")))
        );
        uint24 maxSlippagePIPS = PIPS / 100; // 1% max slippage.

        manager.initManagement(
            SetupParams({
                vault: address(vault),
                oracle: oracle,
                maxDeviation: maxDeviation,
                cooldownPeriod: cooldownPeriod,
                executor: executor,
                stratAnnouncer: stratAnnouncer,
                maxSlippagePIPS: maxSlippagePIPS
            })
        );

        // #endregion whitelist vault.

        assertEq(manager.receiversByToken(USDC), address(0));

        vm.prank(managerOwner);

        manager.setReceiverByToken(address(vault), true, usdcReceiver);

        assertEq(manager.receiversByToken(USDC), usdcReceiver);

        vm.prank(managerOwner);

        manager.submitIncreaseManagerFeePIPS(
            address(vault),
            SafeCast.toUint24(defaultFeePIPS * 2)
        );

        vm.prank(managerOwner);
        vm.expectRevert(
            IArrakisStandardManager.AlreadyPendingIncrease.selector
        );

        manager.submitIncreaseManagerFeePIPS(
            address(vault),
            SafeCast.toUint24(defaultFeePIPS * 2)
        );
    }

    function testSubmitIncreaseManagerFeePIPS() public {
        // #region setManager.

        vault.setManager(address(manager));

        // #endregion setManager.

        // #region whitelist vault.

        uint24 maxDeviation = PIPS / 100; // 1% max deviation.
        uint256 cooldownPeriod = 60;
        address executor = vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strat Announcer")))
        );
        uint24 maxSlippagePIPS = PIPS / 100; // 1% max slippage.

        manager.initManagement(
            SetupParams({
                vault: address(vault),
                oracle: oracle,
                maxDeviation: maxDeviation,
                cooldownPeriod: cooldownPeriod,
                executor: executor,
                stratAnnouncer: stratAnnouncer,
                maxSlippagePIPS: maxSlippagePIPS
            })
        );

        // #endregion whitelist vault.

        assertEq(manager.receiversByToken(USDC), address(0));

        vm.prank(managerOwner);

        manager.setReceiverByToken(address(vault), true, usdcReceiver);

        assertEq(manager.receiversByToken(USDC), usdcReceiver);

        (uint256 submitTimestamp, ) = manager.pendingFeeIncrease(
            address(vault)
        );
        assertEq(submitTimestamp, 0);

        vm.prank(managerOwner);

        manager.submitIncreaseManagerFeePIPS(
            address(vault),
            SafeCast.toUint24(defaultFeePIPS * 2)
        );

        (submitTimestamp, ) = manager.pendingFeeIncrease(address(vault));

        assertEq(submitTimestamp, block.timestamp);
    }

    // #endregion test submitIncreaseManagerFeePIPS.

    // #region test finalizeIncreaseManagerFeePIPS.

    function testFinalizeIncreaseManagerFeePIPSOnlyOwner() public {
        // #region setManager.

        vault.setManager(address(manager));

        // #endregion setManager.

        // #region whitelist vault.

        uint24 maxDeviation = PIPS / 100; // 1% max deviation.
        uint256 cooldownPeriod = 60;
        address executor = vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strat Announcer")))
        );
        uint24 maxSlippagePIPS = PIPS / 100; // 1% max slippage.

        manager.initManagement(
            SetupParams({
                vault: address(vault),
                oracle: oracle,
                maxDeviation: maxDeviation,
                cooldownPeriod: cooldownPeriod,
                executor: executor,
                stratAnnouncer: stratAnnouncer,
                maxSlippagePIPS: maxSlippagePIPS
            })
        );

        // #endregion whitelist vault.

        // #region submit increase.

        assertEq(manager.receiversByToken(USDC), address(0));

        vm.prank(managerOwner);

        manager.setReceiverByToken(address(vault), true, usdcReceiver);

        assertEq(manager.receiversByToken(USDC), usdcReceiver);

        (uint256 submitTimestamp, ) = manager.pendingFeeIncrease(
            address(vault)
        );
        assertEq(submitTimestamp, 0);

        vm.prank(managerOwner);

        manager.submitIncreaseManagerFeePIPS(
            address(vault),
            SafeCast.toUint24(defaultFeePIPS * 2)
        );

        (submitTimestamp, ) = manager.pendingFeeIncrease(address(vault));

        assertEq(submitTimestamp, block.timestamp);

        // #endregion submit increase.

        vm.expectRevert(Ownable.Unauthorized.selector);

        manager.finalizeIncreaseManagerFeePIPS(address(vault));
    }

    function testFinalizeIncreaseManagerFeePIPSNoPendingIncrease() public {
        // #region setManager.

        vault.setManager(address(manager));

        // #endregion setManager.

        // #region whitelist vault.

        uint24 maxDeviation = PIPS / 100; // 1% max deviation.
        uint256 cooldownPeriod = 60;
        address executor = vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strat Announcer")))
        );
        uint24 maxSlippagePIPS = PIPS / 100; // 1% max slippage.

        manager.initManagement(
            SetupParams({
                vault: address(vault),
                oracle: oracle,
                maxDeviation: maxDeviation,
                cooldownPeriod: cooldownPeriod,
                executor: executor,
                stratAnnouncer: stratAnnouncer,
                maxSlippagePIPS: maxSlippagePIPS
            })
        );

        // #endregion whitelist vault.

        vm.expectRevert(IArrakisStandardManager.NoPendingIncrease.selector);
        vm.prank(managerOwner);

        manager.finalizeIncreaseManagerFeePIPS(address(vault));
    }

    function testFinalizeIncreaseManagerFeePIPSTimeNotPassed() public {
        // #region setManager.

        vault.setManager(address(manager));

        // #endregion setManager.

        // #region whitelist vault.

        uint24 maxDeviation = PIPS / 100; // 1% max deviation.
        uint256 cooldownPeriod = 60;
        address executor = vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strat Announcer")))
        );
        uint24 maxSlippagePIPS = PIPS / 100; // 1% max slippage.

        manager.initManagement(
            SetupParams({
                vault: address(vault),
                oracle: oracle,
                maxDeviation: maxDeviation,
                cooldownPeriod: cooldownPeriod,
                executor: executor,
                stratAnnouncer: stratAnnouncer,
                maxSlippagePIPS: maxSlippagePIPS
            })
        );

        // #endregion whitelist vault.

        // #region submit increase.

        assertEq(manager.receiversByToken(USDC), address(0));

        vm.prank(managerOwner);

        manager.setReceiverByToken(address(vault), true, usdcReceiver);

        assertEq(manager.receiversByToken(USDC), usdcReceiver);

        (uint256 submitTimestamp, ) = manager.pendingFeeIncrease(
            address(vault)
        );
        assertEq(submitTimestamp, 0);

        vm.prank(managerOwner);

        manager.submitIncreaseManagerFeePIPS(
            address(vault),
            SafeCast.toUint24(defaultFeePIPS * 2)
        );

        (submitTimestamp, ) = manager.pendingFeeIncrease(address(vault));

        assertEq(submitTimestamp, block.timestamp);

        // #endregion submit increase.

        vm.expectRevert(IArrakisStandardManager.TimeNotPassed.selector);
        vm.prank(managerOwner);

        manager.finalizeIncreaseManagerFeePIPS(address(vault));
    }

    function testFinalizeIncreaseManagerFeePIPS() public {
        // #region setManager.

        vault.setManager(address(manager));

        // #endregion setManager.

        // #region whitelist vault.

        uint24 maxDeviation = PIPS / 100; // 1% max deviation.
        uint256 cooldownPeriod = 60;
        address executor = vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strat Announcer")))
        );
        uint24 maxSlippagePIPS = PIPS / 100; // 1% max slippage.

        manager.initManagement(
            SetupParams({
                vault: address(vault),
                oracle: oracle,
                maxDeviation: maxDeviation,
                cooldownPeriod: cooldownPeriod,
                executor: executor,
                stratAnnouncer: stratAnnouncer,
                maxSlippagePIPS: maxSlippagePIPS
            })
        );

        // #endregion whitelist vault.

        // #region submit increase.

        assertEq(manager.receiversByToken(USDC), address(0));

        vm.prank(managerOwner);

        manager.setReceiverByToken(address(vault), true, usdcReceiver);

        assertEq(manager.receiversByToken(USDC), usdcReceiver);

        (uint256 submitTimestamp, ) = manager.pendingFeeIncrease(
            address(vault)
        );
        assertEq(submitTimestamp, 0);

        vm.prank(managerOwner);

        manager.submitIncreaseManagerFeePIPS(
            address(vault),
            SafeCast.toUint24(defaultFeePIPS * 2)
        );

        (submitTimestamp, ) = manager.pendingFeeIncrease(address(vault));

        assertEq(submitTimestamp, block.timestamp);

        // #endregion submit increase.

        vm.prank(managerOwner);
        vm.warp(block.timestamp + WEEK + 1);

        manager.finalizeIncreaseManagerFeePIPS(address(vault));
    }

    // #endregion test finalizeIncreaseManagerFeePIPS.

    // #region test withdrawManagerBalance.

    function testWithdrawManagerBalanceOnlyOwner() public {
        vm.expectRevert(Ownable.Unauthorized.selector);

        manager.withdrawManagerBalance(address(vault));
    }

    function testWithdrawManagerBalanceUSDC() public {
        // #region mock module.

        uint256 usdcManagerFee = 2000e6;

        module.setManagerBalances(usdcManagerFee, 0);

        deal(USDC, address(module), usdcManagerFee);

        // #endregion mock module.

        // #region setManager.

        vault.setManager(address(manager));

        // #endregion setManager.

        // #region whitelist vault.

        uint24 maxDeviation = PIPS / 100; // 1% max deviation.
        uint256 cooldownPeriod = 60;
        address executor = vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strat Announcer")))
        );
        uint24 maxSlippagePIPS = PIPS / 100; // 1% max slippage.

        manager.initManagement(
            SetupParams({
                vault: address(vault),
                oracle: oracle,
                maxDeviation: maxDeviation,
                cooldownPeriod: cooldownPeriod,
                executor: executor,
                stratAnnouncer: stratAnnouncer,
                maxSlippagePIPS: maxSlippagePIPS
            })
        );

        // #endregion whitelist vault.

        // #region set usdc token receiver.

        assertEq(manager.receiversByToken(USDC), address(0));

        vm.prank(managerOwner);

        manager.setReceiverByToken(address(vault), true, usdcReceiver);

        assertEq(manager.receiversByToken(USDC), usdcReceiver);

        // #endregion set usdc token receiver.

        assertEq(IERC20(USDC).balanceOf(usdcReceiver), 0);

        vm.prank(managerOwner);

        manager.withdrawManagerBalance(address(vault));

        assertEq(IERC20(USDC).balanceOf(usdcReceiver), usdcManagerFee);
    }

    function testWithdrawManagerBalanceUSDCWETH() public {
        // #region mock module.

        uint256 usdcManagerFee = 2000e6;
        uint256 wethManagerFee = 3e18;

        module.setManagerBalances(usdcManagerFee, wethManagerFee);

        deal(USDC, address(module), usdcManagerFee);
        deal(WETH, address(module), wethManagerFee);

        // #endregion mock module.

        // #region setManager.

        vault.setManager(address(manager));

        // #endregion setManager.

        // #region whitelist vault.

        uint24 maxDeviation = PIPS / 100; // 1% max deviation.
        uint256 cooldownPeriod = 60;
        address executor = vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strat Announcer")))
        );
        uint24 maxSlippagePIPS = PIPS / 100; // 1% max slippage.

        manager.initManagement(
            SetupParams({
                vault: address(vault),
                oracle: oracle,
                maxDeviation: maxDeviation,
                cooldownPeriod: cooldownPeriod,
                executor: executor,
                stratAnnouncer: stratAnnouncer,
                maxSlippagePIPS: maxSlippagePIPS
            })
        );

        // #endregion whitelist vault.

        // #region set usdc token receiver.

        assertEq(manager.receiversByToken(USDC), address(0));

        vm.prank(managerOwner);

        manager.setReceiverByToken(address(vault), true, usdcReceiver);

        assertEq(manager.receiversByToken(USDC), usdcReceiver);

        // #endregion set usdc token receiver.

        assertEq(IERC20(USDC).balanceOf(usdcReceiver), 0);
        assertEq(IERC20(WETH).balanceOf(defaultReceiver), 0);

        vm.prank(managerOwner);

        manager.withdrawManagerBalance(address(vault));

        assertEq(IERC20(USDC).balanceOf(usdcReceiver), usdcManagerFee);
        assertEq(IERC20(WETH).balanceOf(defaultReceiver), wethManagerFee);
    }

    // #endregion test withdrawManagerBalance.

    // #region test setModule.

    function testSetModuleOnlyExecutor() public {
        // #region whitelist another module.

        address[] memory modules = new address[](1);

        modules[0] = address(
            new LpModuleMock(USDC, NATIVE_COIN, address(manager))
        );

        vault.whitelistModules(modules);

        bytes[] memory payloads = new bytes[](0);

        // #endregion whitelist another module.

        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisStandardManager.NotWhitelistedVault.selector,
                address(vault)
            )
        );

        manager.setModule(address(vault), modules[0], payloads);
    }

    function testSetModuleNotExecutor() public {
        // #region whitelist another module.

        address[] memory modules = new address[](1);

        modules[0] = address(
            new LpModuleMock(USDC, NATIVE_COIN, address(manager))
        );

        vault.whitelistModules(modules);

        bytes[] memory payloads = new bytes[](0);

        // #endregion whitelist another module.

        // #region setManager.

        vault.setManager(address(manager));

        // #endregion setManager.

        // #region whitelist vault.

        uint24 maxDeviation = PIPS / 100; // 1% max deviation.
        uint256 cooldownPeriod = 60;
        address executor = vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strat Announcer")))
        );
        uint24 maxSlippagePIPS = PIPS / 100; // 1% max slippage.

        manager.initManagement(
            SetupParams({
                vault: address(vault),
                oracle: oracle,
                maxDeviation: maxDeviation,
                cooldownPeriod: cooldownPeriod,
                executor: executor,
                stratAnnouncer: stratAnnouncer,
                maxSlippagePIPS: maxSlippagePIPS
            })
        );

        // #endregion whitelist vault.

        vm.expectRevert(IArrakisStandardManager.NotExecutor.selector);

        manager.setModule(address(vault), modules[0], payloads);
    }

    function testSetModule() public {
        // #region whitelist another module.

        address[] memory modules = new address[](1);

        modules[0] = address(
            new LpModuleMock(USDC, NATIVE_COIN, address(manager))
        );

        vault.whitelistModules(modules);

        bytes[] memory payloads = new bytes[](0);

        // #endregion whitelist another module.

        // #region setManager.

        vault.setManager(address(manager));

        // #endregion setManager.

        // #region whitelist vault.

        uint24 maxDeviation = PIPS / 100; // 1% max deviation.
        uint256 cooldownPeriod = 60;
        address executor = vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strat Announcer")))
        );
        uint24 maxSlippagePIPS = PIPS / 100; // 1% max slippage.

        manager.initManagement(
            SetupParams({
                vault: address(vault),
                oracle: oracle,
                maxDeviation: maxDeviation,
                cooldownPeriod: cooldownPeriod,
                executor: executor,
                stratAnnouncer: stratAnnouncer,
                maxSlippagePIPS: maxSlippagePIPS
            })
        );

        // #endregion whitelist vault.

        vm.prank(executor);

        manager.setModule(address(vault), modules[0], payloads);
    }

    // #endregion test setModule.

    // #region test initManagement.

    function testInitManagementOnlyVaultOwner() public {
        address caller = vm.addr(
            uint256(keccak256(abi.encode("Not the owner of the vault")))
        );

        // #region setManager.

        vault.setManager(address(manager));

        // #endregion setManager.

        // #region whitelist vault.

        uint24 maxDeviation = PIPS / 100; // 1% max deviation.
        uint256 cooldownPeriod = 60;
        address executor = vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strat Announcer")))
        );
        uint24 maxSlippagePIPS = PIPS / 100; // 1% max slippage.

        vm.prank(caller);
        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisStandardManager.OnlyVaultOwner.selector,
                caller,
                address(this)
            )
        );

        manager.initManagement(
            SetupParams({
                vault: address(vault),
                oracle: oracle,
                maxDeviation: maxDeviation,
                cooldownPeriod: cooldownPeriod,
                executor: executor,
                stratAnnouncer: stratAnnouncer,
                maxSlippagePIPS: maxSlippagePIPS
            })
        );

        // #endregion whitelist vault.
    }

    function testInitManagementNotTheManager() public {
        address m = vm.addr(uint256(keccak256(abi.encode("Current Manager"))));
        // #region setManager.

        vault.setManager(m);

        // #endregion setManager.

        // #region whitelist vault.

        uint24 maxDeviation = PIPS / 100; // 1% max deviation.
        uint256 cooldownPeriod = 60;
        address executor = vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strat Announcer")))
        );
        uint24 maxSlippagePIPS = PIPS / 100; // 1% max slippage.

        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisStandardManager.NotTheManager.selector,
                address(manager),
                m
            )
        );

        manager.initManagement(
            SetupParams({
                vault: address(vault),
                oracle: oracle,
                maxDeviation: maxDeviation,
                cooldownPeriod: cooldownPeriod,
                executor: executor,
                stratAnnouncer: stratAnnouncer,
                maxSlippagePIPS: maxSlippagePIPS
            })
        );

        // #endregion whitelist vault.
    }

    function testInitManagementOracleAddressZero() public {
        // #region setManager.

        vault.setManager(address(manager));

        // #endregion setManager.

        uint24 maxDeviation = PIPS / 100; // 1% max deviation.
        uint256 cooldownPeriod = 60;
        address executor = vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strat Announcer")))
        );
        uint24 maxSlippagePIPS = PIPS / 100; // 1% max slippage.

        vm.expectRevert(IArrakisStandardManager.AddressZero.selector);

        manager.initManagement(
            SetupParams({
                vault: address(vault),
                oracle: IOracleWrapper(address(0)),
                maxDeviation: maxDeviation,
                cooldownPeriod: cooldownPeriod,
                executor: executor,
                stratAnnouncer: stratAnnouncer,
                maxSlippagePIPS: maxSlippagePIPS
            })
        );
    }

    function testInitManagementSlippageTooHigh() public {
        // #region setManager.

        vault.setManager(address(manager));

        // #endregion setManager.

        uint24 maxDeviation = PIPS / 100; // 1% max deviation.
        uint256 cooldownPeriod = 60;
        address executor = vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strat Announcer")))
        );
        uint24 maxSlippagePIPS = PIPS / 5; // 20% max slippage.

        vm.expectRevert(IArrakisStandardManager.SlippageTooHigh.selector);

        manager.initManagement(
            SetupParams({
                vault: address(vault),
                oracle: oracle,
                maxDeviation: maxDeviation,
                cooldownPeriod: cooldownPeriod,
                executor: executor,
                stratAnnouncer: stratAnnouncer,
                maxSlippagePIPS: maxSlippagePIPS
            })
        );
    }

    function testInitManagementCooldownPeriodZero() public {
        // #region setManager.

        vault.setManager(address(manager));

        // #endregion setManager.

        uint24 maxDeviation = PIPS / 100; // 1% max deviation.
        uint256 cooldownPeriod = 0;
        address executor = vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strat Announcer")))
        );
        uint24 maxSlippagePIPS = PIPS / 100; // 1% max slippage.

        vm.expectRevert(
            IArrakisStandardManager.CooldownPeriodSetToZero.selector
        );

        manager.initManagement(
            SetupParams({
                vault: address(vault),
                oracle: oracle,
                maxDeviation: maxDeviation,
                cooldownPeriod: cooldownPeriod,
                executor: executor,
                stratAnnouncer: stratAnnouncer,
                maxSlippagePIPS: maxSlippagePIPS
            })
        );
    }

    function testInitManagement() public {
        // #region setManager.

        vault.setManager(address(manager));

        // #endregion setManager.

        uint24 maxDeviation = PIPS / 100; // 1% max deviation.
        uint256 cooldownPeriod = 60;
        address executor = vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strat Announcer")))
        );
        uint24 maxSlippagePIPS = PIPS / 100; // 1% max slippage.

        assertEq(manager.numInitializedVaults(), 0);

        manager.initManagement(
            SetupParams({
                vault: address(vault),
                oracle: oracle,
                maxDeviation: maxDeviation,
                cooldownPeriod: cooldownPeriod,
                executor: executor,
                stratAnnouncer: stratAnnouncer,
                maxSlippagePIPS: maxSlippagePIPS
            })
        );

        assertEq(manager.numInitializedVaults(), 1);
    }

    // #endregion test initManagement.

    // #region test updateVaultInfo.

    function testUpdateVaultInfoOnlyWhitelistedVault() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisStandardManager.NotWhitelistedVault.selector,
                address(vault)
            )
        );

        uint24 maxDeviation = PIPS / 100; // 1% max deviation.
        uint256 cooldownPeriod = 60;
        address executor = vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strat Announcer")))
        );
        uint24 maxSlippagePIPS = PIPS / 100; // 1% max slippage.

        manager.updateVaultInfo(
            SetupParams({
                vault: address(vault),
                oracle: oracle,
                maxDeviation: maxDeviation,
                cooldownPeriod: cooldownPeriod,
                executor: executor,
                stratAnnouncer: stratAnnouncer,
                maxSlippagePIPS: maxSlippagePIPS
            })
        );
    }

    function testUpdateVaultInfoOnlyVaultOwner() public {
        address caller = vm.addr(
            uint256(keccak256(abi.encode("Not the Vault Owner")))
        );

        // #region setManager.

        vault.setManager(address(manager));

        // #endregion setManager.

        uint24 maxDeviation = PIPS / 100; // 1% max deviation.
        uint256 cooldownPeriod = 60;
        address executor = vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strat Announcer")))
        );
        uint24 maxSlippagePIPS = PIPS / 100; // 1% max slippage.

        assertEq(manager.numInitializedVaults(), 0);

        manager.initManagement(
            SetupParams({
                vault: address(vault),
                oracle: oracle,
                maxDeviation: maxDeviation,
                cooldownPeriod: cooldownPeriod,
                executor: executor,
                stratAnnouncer: stratAnnouncer,
                maxSlippagePIPS: maxSlippagePIPS
            })
        );

        assertEq(manager.numInitializedVaults(), 1);

        cooldownPeriod = 120;

        vm.prank(caller);
        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisStandardManager.OnlyVaultOwner.selector,
                caller,
                address(this)
            )
        );

        manager.updateVaultInfo(
            SetupParams({
                vault: address(vault),
                oracle: oracle,
                maxDeviation: maxDeviation,
                cooldownPeriod: cooldownPeriod,
                executor: executor,
                stratAnnouncer: stratAnnouncer,
                maxSlippagePIPS: maxSlippagePIPS
            })
        );
    }

    function testUpdateVaultInfoNotManager() public {
        // #region setManager.

        vault.setManager(address(manager));

        // #endregion setManager.

        uint24 maxDeviation = PIPS / 100; // 1% max deviation.
        uint256 cooldownPeriod = 60;
        address executor = vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strat Announcer")))
        );
        uint24 maxSlippagePIPS = PIPS / 100; // 1% max slippage.

        assertEq(manager.numInitializedVaults(), 0);

        manager.initManagement(
            SetupParams({
                vault: address(vault),
                oracle: oracle,
                maxDeviation: maxDeviation,
                cooldownPeriod: cooldownPeriod,
                executor: executor,
                stratAnnouncer: stratAnnouncer,
                maxSlippagePIPS: maxSlippagePIPS
            })
        );

        assertEq(manager.numInitializedVaults(), 1);

        cooldownPeriod = 120;

        // #region change manager.

        address newManager = vm.addr(
            uint256(keccak256(abi.encode("New Manager")))
        );

        vault.setManager(newManager);

        // #endregion change manager.

        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisStandardManager.NotTheManager.selector,
                address(manager),
                newManager
            )
        );

        manager.updateVaultInfo(
            SetupParams({
                vault: address(vault),
                oracle: oracle,
                maxDeviation: maxDeviation,
                cooldownPeriod: cooldownPeriod,
                executor: executor,
                stratAnnouncer: stratAnnouncer,
                maxSlippagePIPS: maxSlippagePIPS
            })
        );
    }

    function testUpdateVaultOracleAddressZero() public {
        // #region setManager.

        vault.setManager(address(manager));

        // #endregion setManager.

        uint24 maxDeviation = PIPS / 100; // 1% max deviation.
        uint256 cooldownPeriod = 60;
        address executor = vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strat Announcer")))
        );
        uint24 maxSlippagePIPS = PIPS / 100; // 1% max slippage.

        assertEq(manager.numInitializedVaults(), 0);

        manager.initManagement(
            SetupParams({
                vault: address(vault),
                oracle: oracle,
                maxDeviation: maxDeviation,
                cooldownPeriod: cooldownPeriod,
                executor: executor,
                stratAnnouncer: stratAnnouncer,
                maxSlippagePIPS: maxSlippagePIPS
            })
        );

        assertEq(manager.numInitializedVaults(), 1);

        cooldownPeriod = 120;

        vm.expectRevert(IArrakisStandardManager.AddressZero.selector);

        manager.updateVaultInfo(
            SetupParams({
                vault: address(vault),
                oracle: IOracleWrapper(address(0)),
                maxDeviation: maxDeviation,
                cooldownPeriod: cooldownPeriod,
                executor: executor,
                stratAnnouncer: stratAnnouncer,
                maxSlippagePIPS: maxSlippagePIPS
            })
        );
    }

    function testUpdateVaultSlippageTooHigh() public {
        // #region setManager.

        vault.setManager(address(manager));

        // #endregion setManager.

        uint24 maxDeviation = PIPS / 100; // 1% max deviation.
        uint256 cooldownPeriod = 60;
        address executor = vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strat Announcer")))
        );
        uint24 maxSlippagePIPS = PIPS / 100; // 1% max slippage.

        assertEq(manager.numInitializedVaults(), 0);

        manager.initManagement(
            SetupParams({
                vault: address(vault),
                oracle: oracle,
                maxDeviation: maxDeviation,
                cooldownPeriod: cooldownPeriod,
                executor: executor,
                stratAnnouncer: stratAnnouncer,
                maxSlippagePIPS: maxSlippagePIPS
            })
        );

        assertEq(manager.numInitializedVaults(), 1);

        cooldownPeriod = 120;
        maxSlippagePIPS = PIPS / 5;

        vm.expectRevert(IArrakisStandardManager.SlippageTooHigh.selector);

        manager.updateVaultInfo(
            SetupParams({
                vault: address(vault),
                oracle: oracle,
                maxDeviation: maxDeviation,
                cooldownPeriod: cooldownPeriod,
                executor: executor,
                stratAnnouncer: stratAnnouncer,
                maxSlippagePIPS: maxSlippagePIPS
            })
        );
    }

    function testUpdateVaultCooldownPeriodZero() public {
        // #region setManager.

        vault.setManager(address(manager));

        // #endregion setManager.

        uint24 maxDeviation = PIPS / 100; // 1% max deviation.
        uint256 cooldownPeriod = 60;
        address executor = vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strat Announcer")))
        );
        uint24 maxSlippagePIPS = PIPS / 100; // 1% max slippage.

        assertEq(manager.numInitializedVaults(), 0);

        manager.initManagement(
            SetupParams({
                vault: address(vault),
                oracle: oracle,
                maxDeviation: maxDeviation,
                cooldownPeriod: cooldownPeriod,
                executor: executor,
                stratAnnouncer: stratAnnouncer,
                maxSlippagePIPS: maxSlippagePIPS
            })
        );

        assertEq(manager.numInitializedVaults(), 1);

        cooldownPeriod = 0;

        vm.expectRevert(
            IArrakisStandardManager.CooldownPeriodSetToZero.selector
        );

        manager.updateVaultInfo(
            SetupParams({
                vault: address(vault),
                oracle: oracle,
                maxDeviation: maxDeviation,
                cooldownPeriod: cooldownPeriod,
                executor: executor,
                stratAnnouncer: stratAnnouncer,
                maxSlippagePIPS: maxSlippagePIPS
            })
        );
    }

    function testUpdateVault() public {
        // #region setManager.

        vault.setManager(address(manager));

        // #endregion setManager.

        uint24 maxDeviation = PIPS / 100; // 1% max deviation.
        uint256 cooldownPeriod = 60;
        address executor = vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address stratAnnouncer = vm.addr(
            uint256(keccak256(abi.encode("Strat Announcer")))
        );
        uint24 maxSlippagePIPS = PIPS / 100; // 1% max slippage.

        assertEq(manager.numInitializedVaults(), 0);

        manager.initManagement(
            SetupParams({
                vault: address(vault),
                oracle: oracle,
                maxDeviation: maxDeviation,
                cooldownPeriod: cooldownPeriod,
                executor: executor,
                stratAnnouncer: stratAnnouncer,
                maxSlippagePIPS: maxSlippagePIPS
            })
        );

        assertEq(manager.numInitializedVaults(), 1);

        cooldownPeriod = 120;

        manager.updateVaultInfo(
            SetupParams({
                vault: address(vault),
                oracle: oracle,
                maxDeviation: maxDeviation,
                cooldownPeriod: cooldownPeriod,
                executor: executor,
                stratAnnouncer: stratAnnouncer,
                maxSlippagePIPS: maxSlippagePIPS
            })
        );
    }

    // #endregion test updateVaultInfo.
}
