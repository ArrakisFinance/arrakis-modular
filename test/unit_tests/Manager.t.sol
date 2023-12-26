// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {console} from "forge-std/console.sol";

import {TestWrapper} from "../utils/TestWrapper.sol";
import {Manager, IManager} from "../../src/Manager.sol";

import {LpModuleMock} from "../mocks/LpModuleMock.sol";
import {ArrakisMetaVaultMock} from "../mocks/ArrakisMetaVaultMock.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ManagerTest is TestWrapper {
    // #region constant properties.

    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    // #endregion constant properties.

    Manager public manager;
    address public owner;
    address public defaultReceiver;
    address public token0Receiver;
    address public token1Receiver;

    function setUp() public {
        owner = vm.addr(1);
        defaultReceiver = vm.addr(2);
        token0Receiver = vm.addr(3);
        token1Receiver = vm.addr(4);
        manager = new Manager(owner, defaultReceiver);
    }

    // #region constructor.

    function testConstructorWithOwnerAddressZero() public {
        vm.expectRevert(IManager.AddressZero.selector);
        manager = new Manager(address(0), defaultReceiver);
    }

    function testConstructorWithDefaultReceiverAddressZero() public {
        vm.expectRevert(IManager.AddressZero.selector);
        manager = new Manager(owner, address(0));
    }

    function testConstructor() public {
        manager = new Manager(owner, defaultReceiver);

        assertEq(manager.owner(), owner);
        assertEq(manager.defaultReceiver(), defaultReceiver);
    }

    // #endregion constructor.

    // #region test set default receiver.

    function testDefaultReceiverAsZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(IManager.AddressZero.selector);
        manager.setDefaultReceiver(address(0));
    }

    function testDefaultReceiverOnlyOwner() public {
        vm.expectRevert(0x82b42900);

        address newDefaultReceiver = vm.addr(10);

        manager.setDefaultReceiver(newDefaultReceiver);
    }

    function testDefaultReceiver() public {
        address newDefaultReceiver = vm.addr(10);

        assertEq(manager.defaultReceiver(), defaultReceiver);

        vm.prank(owner);

        manager.setDefaultReceiver(newDefaultReceiver);

        assertEq(manager.defaultReceiver(), newDefaultReceiver);
    }

    // #endregion test set default receiver.

    // #region test whitelist a vault.

    function testWhitelistEmptyArray() public {
        address[] memory vaults = new address[](0);

        vm.prank(owner);

        vm.expectRevert(IManager.EmptyVaultsArray.selector);

        manager.whitelistVaults(vaults);
    }

    function testWhitelistNotOwner() public {
        address[] memory vaults = new address[](1);
        vaults[0] = vm.addr(10);

        vm.expectRevert(0x82b42900);

        manager.whitelistVaults(vaults);
    }

    function testWhitelistAddressZero() public {
        address[] memory vaults = new address[](1);
        vaults[0] = address(0);

        vm.prank(owner);

        vm.expectRevert(IManager.AddressZero.selector);

        manager.whitelistVaults(vaults);
    }

    function testwhitelistVaults() public {
        address[] memory vaults = new address[](2);
        vaults[0] = vm.addr(10);
        vaults[1] = vm.addr(11);

        vm.prank(owner);

        manager.whitelistVaults(vaults);

        address[] memory currentVaults = manager.whitelistedVaults();

        assertEq(vaults[0], currentVaults[0]);
        assertEq(vaults[1], currentVaults[1]);
    }

    function testWhitelistAlreadyWhitelistedVault() public {
        address[] memory vaults = new address[](2);
        vaults[0] = vm.addr(10);
        vaults[1] = vm.addr(11);

        vm.prank(owner);

        manager.whitelistVaults(vaults);

        address[] memory currentVaults = manager.whitelistedVaults();

        assertEq(vaults[0], currentVaults[0]);
        assertEq(vaults[1], currentVaults[1]);

        vaults[0] = vm.addr(12);

        vm.prank(owner);

        vm.expectRevert(
            abi.encodeWithSelector(
                IManager.AlreadyWhitelistedVault.selector,
                vaults[1]
            )
        );

        manager.whitelistVaults(vaults);
    }

    // #endregion test whitelist a vault.


    // #region test whitelist a rebalancer.

    function testWhitelistRebalancerEmptyArray() public {
        address[] memory rebalancers = new address[](0);

        vm.prank(owner);

        vm.expectRevert(IManager.EmptyRebalancersArray.selector);

        manager.whitelistRebalancers(rebalancers);
    }

    function testWhitelistRebalancerNotOwner() public {
        address[] memory rebalancers = new address[](1);
        rebalancers[0] = vm.addr(10);

        vm.expectRevert(0x82b42900);

        manager.whitelistRebalancers(rebalancers);
    }

    function testWhitelistRebalancerAddressZero() public {
        address[] memory rebalancers = new address[](1);
        rebalancers[0] = address(0);

        vm.prank(owner);

        vm.expectRevert(IManager.AddressZero.selector);

        manager.whitelistRebalancers(rebalancers);
    }

    function testwhitelistRebalancer() public {
        address[] memory rebalancers = new address[](2);
        rebalancers[0] = vm.addr(10);
        rebalancers[1] = vm.addr(11);

        vm.prank(owner);

        manager.whitelistRebalancers(rebalancers);

        address[] memory currentRebalancers = manager.whitelistedRebalancers();

        assertEq(rebalancers[0], currentRebalancers[0]);
        assertEq(rebalancers[1], currentRebalancers[1]);
    }

    function testWhitelistAlreadyWhitelistedRebalancer() public {
        address[] memory rebalancers = new address[](2);
        rebalancers[0] = vm.addr(10);
        rebalancers[1] = vm.addr(11);

        vm.prank(owner);

        manager.whitelistRebalancers(rebalancers);

        address[] memory currentRebalancers = manager.whitelistedRebalancers();

        assertEq(rebalancers[0], currentRebalancers[0]);
        assertEq(rebalancers[1], currentRebalancers[1]);

        rebalancers[0] = vm.addr(12);

        vm.prank(owner);

        vm.expectRevert(
            abi.encodeWithSelector(
                IManager.AlreadyWhitelistedRebalancer.selector,
                rebalancers[1]
            )
        );

        manager.whitelistRebalancers(rebalancers);
    }

    // #endregion test whitelist a rebalancer.

    // #region test blacklist vault.

    function testBlacklistEmptyArray() public {
        address[] memory vaults = new address[](0);

        vm.prank(owner);

        vm.expectRevert(IManager.EmptyVaultsArray.selector);

        manager.blacklistVaults(vaults);
    }

    function testBacklistNotOwner() public {
        address[] memory vaults = new address[](1);
        vaults[0] = vm.addr(10);

        vm.expectRevert(0x82b42900);

        manager.blacklistVaults(vaults);
    }

    function testBlacklistVaults() public {
        address[] memory vaults = new address[](2);
        vaults[0] = vm.addr(10);
        vaults[1] = vm.addr(11);

        vm.prank(owner);

        manager.whitelistVaults(vaults);

        address[] memory currentVaults = manager.whitelistedVaults();

        assertEq(vaults[0], currentVaults[0]);
        assertEq(vaults[1], currentVaults[1]);

        vm.prank(owner);

        manager.blacklistVaults(vaults);
    }

    function testBlacklistAddressZero() public {
        address[] memory vaults = new address[](1);
        vaults[0] = address(0);

        vm.prank(owner);

        vm.expectRevert(IManager.AddressZero.selector);

        manager.blacklistVaults(vaults);
    }

    function testBlacklistNotAlreadyWhitelisted() public {
        address[] memory vaults = new address[](2);
        vaults[0] = vm.addr(10);
        vaults[1] = vm.addr(11);

        vm.prank(owner);

        vm.expectRevert(
            abi.encodeWithSelector(
                IManager.NotWhitelistedVault.selector,
                vaults[0]
            )
        );

        manager.blacklistVaults(vaults);
    }

    // #endregion test blacklist vault.

    // #region test blacklist rebalancers.

    function testBlacklistRebalancersEmptyArray() public {
        address[] memory rebalancers = new address[](0);

        vm.prank(owner);

        vm.expectRevert(IManager.EmptyRebalancersArray.selector);

        manager.blacklistRebalancers(rebalancers);
    }

    function testBacklistRebalancersNotOwner() public {
        address[] memory rebalancers = new address[](1);
        rebalancers[0] = vm.addr(10);

        vm.expectRevert(0x82b42900);

        manager.blacklistRebalancers(rebalancers);
    }

    function testBlacklistRebalancers() public {
        address[] memory rebalancers = new address[](2);
        rebalancers[0] = vm.addr(10);
        rebalancers[1] = vm.addr(11);

        vm.prank(owner);

        manager.whitelistRebalancers(rebalancers);

        address[] memory currentRebalancers = manager.whitelistedRebalancers();

        assertEq(rebalancers[0], currentRebalancers[0]);
        assertEq(rebalancers[1], currentRebalancers[1]);

        vm.prank(owner);

        manager.blacklistRebalancers(rebalancers);
    }

    function testBlacklistRebalancersAddressZero() public {
        address[] memory rebalancers = new address[](1);
        rebalancers[0] = address(0);

        vm.prank(owner);

        vm.expectRevert(IManager.AddressZero.selector);

        manager.blacklistRebalancers(rebalancers);
    }

    function testBlacklistNotAlreadyWhitelistedRebalancers() public {
        address[] memory rebalancers = new address[](2);
        rebalancers[0] = vm.addr(10);
        rebalancers[1] = vm.addr(11);

        vm.prank(owner);

        vm.expectRevert(
            abi.encodeWithSelector(
                IManager.NotWhitelistedRebalancer.selector,
                rebalancers[0]
            )
        );

        manager.blacklistRebalancers(rebalancers);
    }

    // #endregion test blacklist rebalancers.

    // #region test set receiver by token.

    function testSetReceiverByTokenNotOwner() public {
        // #region whitelist a vault.

        LpModuleMock module = new LpModuleMock(WETH, USDC, address(manager));
        ArrakisMetaVaultMock metaVault = new ArrakisMetaVaultMock(WETH, USDC);
        bytes[] memory payloads = new bytes[](0);
        metaVault.setModule(address(module), payloads);

        address[] memory vaults = new address[](1);
        vaults[0] = address(metaVault);

        vm.prank(owner);

        manager.whitelistVaults(vaults);

        address[] memory currentVaults = manager.whitelistedVaults();

        assertEq(vaults[0], currentVaults[0]);

        // #endregion whitelist a vault.

        address receiver = vm.addr(20);

        vm.expectRevert(0x82b42900);

        manager.setReceiverByToken(vaults[0], true, receiver);
    }

    function testSetReceiverByTokenNotWhitelistedVault() public {
        LpModuleMock module = new LpModuleMock(WETH, USDC, address(manager));
        ArrakisMetaVaultMock metaVault = new ArrakisMetaVaultMock(WETH, USDC);
        bytes[] memory payloads = new bytes[](0);
        metaVault.setModule(address(module), payloads);

        address receiver = vm.addr(20);

        vm.expectRevert(
            abi.encodeWithSelector(
                IManager.NotWhitelistedVault.selector,
                address(metaVault)
            )
        );

        vm.prank(owner);

        manager.setReceiverByToken(address(metaVault), true, receiver);
    }

    function testSetReceiverByTokenReceiverAddressZero() public {
        // #region whitelist a vault.

        LpModuleMock module = new LpModuleMock(WETH, USDC, address(manager));
        ArrakisMetaVaultMock metaVault = new ArrakisMetaVaultMock(WETH, USDC);
        bytes[] memory payloads = new bytes[](0);
        metaVault.setModule(address(module), payloads);

        address[] memory vaults = new address[](1);
        vaults[0] = address(metaVault);

        vm.prank(owner);

        manager.whitelistVaults(vaults);

        address[] memory currentVaults = manager.whitelistedVaults();

        assertEq(vaults[0], currentVaults[0]);

        // #endregion whitelist a vault.

        vm.expectRevert(IManager.AddressZero.selector);

        vm.prank(owner);

        manager.setReceiverByToken(address(metaVault), true, address(0));
    }

    function testSetReceiverByToken() public {
        // #region whitelist a vault.

        LpModuleMock module = new LpModuleMock(WETH, USDC, address(manager));
        ArrakisMetaVaultMock metaVault = new ArrakisMetaVaultMock(WETH, USDC);
        bytes[] memory payloads = new bytes[](0);
        metaVault.setModule(address(module), payloads);

        address[] memory vaults = new address[](1);
        vaults[0] = address(metaVault);

        vm.prank(owner);

        manager.whitelistVaults(vaults);

        address[] memory currentVaults = manager.whitelistedVaults();

        assertEq(vaults[0], currentVaults[0]);

        // #endregion whitelist a vault.

        vm.prank(owner);

        address receiver = vm.addr(20);

        manager.setReceiverByToken(address(metaVault), true, receiver);

        assertEq(receiver, manager.receiversByToken(WETH));
    }

    // #endregion test set receiver by token.

    // #region test withdraw manager balances.

    function testWithdrawManagerBalanceNotWhitelistedVault() public {
        LpModuleMock module = new LpModuleMock(WETH, USDC, address(manager));
        ArrakisMetaVaultMock metaVault = new ArrakisMetaVaultMock(WETH, USDC);
        bytes[] memory payloads = new bytes[](0);
        metaVault.setModule(address(module), payloads);

        vm.expectRevert(
            abi.encodeWithSelector(
                IManager.NotWhitelistedVault.selector,
                address(metaVault)
            )
        );

        vm.prank(owner);

        manager.withdrawManagerBalance(address(metaVault));
    }

    function testWithdrawManagerBalanceNotOwner() public {
        LpModuleMock module = new LpModuleMock(WETH, USDC, address(manager));
        ArrakisMetaVaultMock metaVault = new ArrakisMetaVaultMock(WETH, USDC);
        bytes[] memory payloads = new bytes[](0);
        metaVault.setModule(address(module), payloads);

        vm.expectRevert(0x82b42900);

        manager.withdrawManagerBalance(address(metaVault));
    }

    function testWithdrawManagerBalance() public {
        LpModuleMock module = new LpModuleMock(WETH, USDC, address(manager));
        ArrakisMetaVaultMock metaVault = new ArrakisMetaVaultMock(WETH, USDC);
        bytes[] memory payloads = new bytes[](0);
        metaVault.setModule(address(module), payloads);

        uint256 amount0 = 1e18;
        uint256 amount1 = 2000e6;

        deal(WETH, address(module), amount0);
        deal(USDC, address(module), amount1);

        module.setManagerBalances(amount0, amount1);

        // #region whitelist vault.

        address[] memory vaults = new address[](1);
        vaults[0] = address(metaVault);

        vm.prank(owner);

        manager.whitelistVaults(vaults);

        address[] memory currentVaults = manager.whitelistedVaults();

        assertEq(vaults[0], currentVaults[0]);

        // #endregion whitelist vault.

        // #region set custom receiver for WETH.

        vm.prank(owner);

        address receiver = vm.addr(20);

        manager.setReceiverByToken(address(metaVault), true, receiver);

        assertEq(receiver, manager.receiversByToken(WETH));

        // #endregion set custom receiver for WETH.

        uint256 wethReceiverBalanceBefore = IERC20(WETH).balanceOf(receiver);
        uint256 usdcDefaultReceiverBalanceBefore = IERC20(USDC).balanceOf(
            defaultReceiver
        );

        assertEq(wethReceiverBalanceBefore, 0);
        assertEq(usdcDefaultReceiverBalanceBefore, 0);

        vm.prank(owner);

        manager.withdrawManagerBalance(address(metaVault));

        uint256 wethReceiverBalanceAfter = IERC20(WETH).balanceOf(receiver);
        uint256 usdcDefaultReceiverBalanceAfter = IERC20(USDC).balanceOf(
            defaultReceiver
        );

        assertEq(wethReceiverBalanceAfter, amount0);
        assertEq(usdcDefaultReceiverBalanceAfter, amount1);
    }

    // #endregion test withdraw manager balances.

    // #region test setModule.

    function testSetModuleNotOwner() public {
        LpModuleMock module = new LpModuleMock(WETH, USDC, address(manager));
        ArrakisMetaVaultMock metaVault = new ArrakisMetaVaultMock(WETH, USDC);
        bytes[] memory payloads = new bytes[](0);

        // #region whitelist vault.

        address[] memory vaults = new address[](1);
        vaults[0] = address(metaVault);

        vm.prank(owner);

        manager.whitelistVaults(vaults);

        address[] memory currentVaults = manager.whitelistedVaults();

        assertEq(vaults[0], currentVaults[0]);

        // #endregion whitelist vault.

        vm.expectRevert(0x82b42900);

        manager.setModule(address(metaVault), address(module), payloads);
    }

    function testSetModuleNotWhitelistedVault() public {
        LpModuleMock module = new LpModuleMock(WETH, USDC, address(manager));
        ArrakisMetaVaultMock metaVault = new ArrakisMetaVaultMock(WETH, USDC);
        bytes[] memory payloads = new bytes[](0);

        vm.prank(owner);

        vm.expectRevert(
            abi.encodeWithSelector(
                IManager.NotWhitelistedVault.selector,
                address(metaVault)
            )
        );

        manager.setModule(address(metaVault), address(module), payloads);
    }

    function testSetModule() public {
        LpModuleMock module = new LpModuleMock(WETH, USDC, address(manager));
        ArrakisMetaVaultMock metaVault = new ArrakisMetaVaultMock(WETH, USDC);
        bytes[] memory payloads = new bytes[](0);

        // #region whitelist vault.

        address[] memory vaults = new address[](1);
        vaults[0] = address(metaVault);

        vm.prank(owner);

        manager.whitelistVaults(vaults);

        address[] memory currentVaults = manager.whitelistedVaults();

        assertEq(vaults[0], currentVaults[0]);

        // #endregion whitelist vault.

        vm.prank(owner);

        manager.setModule(address(metaVault), address(module), payloads);

        assertEq(address(metaVault.module()), address(module));
    }

    // #endregion test setModule.

    // #region test set manager fee pips.

    function testSetManagerFeePIPSNotOwner() public {
        LpModuleMock module = new LpModuleMock(WETH, USDC, address(manager));
        ArrakisMetaVaultMock metaVault = new ArrakisMetaVaultMock(WETH, USDC);
        bytes[] memory payloads = new bytes[](0);

        // #region whitelist vault.

        address[] memory vaults = new address[](1);
        vaults[0] = address(metaVault);

        vm.prank(owner);

        manager.whitelistVaults(vaults);

        address[] memory currentVaults = manager.whitelistedVaults();

        assertEq(vaults[0], currentVaults[0]);

        // #endregion whitelist vault.

        uint256[] memory feesPIPS = new uint256[](1);

        feesPIPS[0] = 100_000;

        vm.expectRevert(0x82b42900);

        manager.setManagerFeePIPS(vaults, feesPIPS);
    }

    function testSetManagerFeePIPSNotSameLengthArray() public {
        LpModuleMock module = new LpModuleMock(WETH, USDC, address(manager));
        ArrakisMetaVaultMock metaVault = new ArrakisMetaVaultMock(WETH, USDC);
        bytes[] memory payloads = new bytes[](0);

        // #region whitelist vault.

        address[] memory vaults = new address[](1);
        vaults[0] = address(metaVault);

        vm.prank(owner);

        manager.whitelistVaults(vaults);

        address[] memory currentVaults = manager.whitelistedVaults();

        assertEq(vaults[0], currentVaults[0]);

        // #endregion whitelist vault.

        uint256[] memory feesPIPS = new uint256[](0);

        vm.expectRevert(
            abi.encodeWithSelector(IManager.NotSameLengthArray.selector, 1, 0)
        );

        vm.prank(owner);

        manager.setManagerFeePIPS(vaults, feesPIPS);
    }

    function testSetManagerFeePIPSNotWhitelisted() public {
        LpModuleMock module = new LpModuleMock(WETH, USDC, address(manager));
        ArrakisMetaVaultMock metaVault = new ArrakisMetaVaultMock(WETH, USDC);
        bytes[] memory payloads = new bytes[](0);

        // #region whitelist vault.

        address[] memory vaults = new address[](1);
        vaults[0] = address(metaVault);

        // #endregion whitelist vault.

        uint256[] memory feesPIPS = new uint256[](1);

        feesPIPS[0] = 100_000;

        vm.expectRevert(
            abi.encodeWithSelector(
                IManager.NotWhitelistedVault.selector,
                address(metaVault)
            )
        );

        vm.prank(owner);

        manager.setManagerFeePIPS(vaults, feesPIPS);
    }

    function testSetManagerFeePIPS() public {
        LpModuleMock module = new LpModuleMock(WETH, USDC, address(manager));
        ArrakisMetaVaultMock metaVault = new ArrakisMetaVaultMock(WETH, USDC);
        bytes[] memory payloads = new bytes[](0);
        metaVault.setModule(address(module), payloads);

        // #region whitelist vault.

        address[] memory vaults = new address[](1);
        vaults[0] = address(metaVault);

        vm.prank(owner);

        manager.whitelistVaults(vaults);

        address[] memory currentVaults = manager.whitelistedVaults();

        assertEq(vaults[0], currentVaults[0]);

        // #endregion whitelist vault.

        uint256[] memory feesPIPS = new uint256[](1);

        feesPIPS[0] = 100_000;

        vm.prank(owner);

        manager.setManagerFeePIPS(vaults, feesPIPS);

        assertEq(module.managerFeePIPS(), 100_000);
    }

    // #endregion test set manager fee pips.

    // #region test whitelistedVaults view functions.

    function testWhitelistedVaults() public {
        // #region whitelist two vaults.

        address[] memory vaults = new address[](2);
        vaults[0] = vm.addr(10);
        vaults[1] = vm.addr(11);

        vm.prank(owner);

        manager.whitelistVaults(vaults);

        // #endregion whitelist two vaults.

        address[] memory actualVaults = manager.whitelistedVaults();

        assertEq(vaults[0], actualVaults[0]);
        assertEq(vaults[1], actualVaults[1]);
    }

    // #endregion test whitelistedVaults view functions.
}
