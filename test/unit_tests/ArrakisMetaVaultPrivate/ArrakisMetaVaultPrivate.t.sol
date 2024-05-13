// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

import {TestWrapper} from "../../utils/TestWrapper.sol";

import {ArrakisMetaVaultPrivate} from
    "../../../src/ArrakisMetaVaultPrivate.sol";
import {IArrakisMetaVaultPrivate} from
    "../../../src/interfaces/IArrakisMetaVaultPrivate.sol";
import {IArrakisMetaVault} from
    "../../../src/interfaces/IArrakisMetaVault.sol";
import {PIPS} from "../../../src/constants/CArrakis.sol";
import {PALMVaultNFT} from "../../../src/PALMVaultNFT.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeCast} from
    "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {FullMath} from "@v3-lib-0.8/contracts/FullMath.sol";

// #region mocks.

import {LpModuleMock} from "./mocks/LpModuleMock.sol";

// #endregion mocks.

contract ArrakisMetaVaultPrivateTest is TestWrapper {
    // #region constant properties.

    address public constant WETH =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    // #endregion constant properties.

    ArrakisMetaVaultPrivate public vault;
    LpModuleMock public module;
    PALMVaultNFT public nft;
    address public receiver;
    address public manager;
    address public moduleRegistry;

    function setUp() public {
        manager = vm.addr(uint256(keccak256(abi.encode("Manager"))));
        moduleRegistry =
            vm.addr(uint256(keccak256(abi.encode("Module Registry"))));
        receiver = vm.addr(uint256(keccak256(abi.encode("Receiver"))));

        // #region create module.

        module = new LpModuleMock();
        module.setToken0AndToken1(USDC, WETH);

        // #endregion create module.

        nft = new PALMVaultNFT();

        vault = new ArrakisMetaVaultPrivate(
            moduleRegistry, manager, USDC, WETH, address(nft)
        );

        // #region mint nft.

        nft.mint(address(this), uint256(uint160(address(vault))));

        // #endregion mint nft.

        // #region initialize vault.

        vault.initialize(address(module));

        // #endregion initiliaze vault.
    }

    // #region test constructor.

    function testConstructorNftAddressZero() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisMetaVault.AddressZero.selector, "NFT"
            )
        );

        vault = new ArrakisMetaVaultPrivate(
            moduleRegistry, manager, USDC, WETH, address(0)
        );
    }

    function testConstructorAndInitializeStorage() public {
        address actualModule = address(vault.module());
        address[] memory whitelistedModules =
            vault.whitelistedModules();

        assertEq(vault.token0(), USDC);
        assertEq(vault.token1(), WETH);
        assertEq(vault.nft(), address(nft));
        assertEq(vault.moduleRegistry(), moduleRegistry);
        assertEq(vault.manager(), manager);
        assert(whitelistedModules.length == 1);
        assertEq(whitelistedModules[0], address(module));
        assertEq(actualModule, address(module));
    }

    // #endregion test constructor.

    // #region test deposit.

    function testDepositNotDepositor() public {
        address caller =
            vm.addr(uint256(keccak256(abi.encode("Caller"))));

        uint256 amount0 = 2000e6;
        uint256 amount1 = 1e18;

        deal(USDC, caller, amount0);
        deal(WETH, caller, amount1);

        // #region approve module.

        vm.startPrank(caller);

        IERC20(USDC).approve(address(module), amount0);
        IERC20(WETH).approve(address(module), amount1);

        // #endregion approve module.

        vm.expectRevert(
            IArrakisMetaVaultPrivate.OnlyDepositor.selector
        );

        vault.deposit(amount0, amount1);

        vm.stopPrank();
    }

    function testDeposit() public {
        // #region whitelist depositor.

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));
        address[] memory depositors = new address[](1);
        depositors[0] = depositor;

        address[] memory currentDepositors = vault.depositors();

        assertEq(currentDepositors.length, 0);

        vault.whitelistDepositors(depositors);

        currentDepositors = vault.depositors();

        assertEq(currentDepositors.length, 1);
        assertEq(currentDepositors[0], depositor);

        // #endregion whitelist depositor.

        uint256 amount0 = 2000e6;
        uint256 amount1 = 1e18;

        deal(USDC, address(depositor), amount0);
        deal(WETH, address(depositor), amount1);

        vm.startPrank(depositor);

        // #region approve module.

        IERC20(USDC).approve(address(module), amount0);
        IERC20(WETH).approve(address(module), amount1);

        // #endregion approve module.

        vault.deposit(amount0, amount1);

        vm.stopPrank();
    }

    // #endregion test deposit.

    // #region test withdraw.

    function testWithdrawNotOwner() public {
        address caller =
            vm.addr(uint256(keccak256(abi.encode("Caller"))));
        // #region deposit.

        // #region whitelist depositor.

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));
        address[] memory depositors = new address[](1);
        depositors[0] = depositor;

        address[] memory currentDepositors = vault.depositors();

        assertEq(currentDepositors.length, 0);

        vault.whitelistDepositors(depositors);

        currentDepositors = vault.depositors();

        assertEq(currentDepositors.length, 1);
        assertEq(currentDepositors[0], depositor);

        // #endregion whitelist depositor.

        uint256 amount0 = 2000e6;
        uint256 amount1 = 1e18;

        deal(USDC, address(depositor), amount0);
        deal(WETH, address(depositor), amount1);

        vm.startPrank(depositor);

        // #region approve module.

        IERC20(USDC).approve(address(module), amount0);
        IERC20(WETH).approve(address(module), amount1);

        // #endregion approve module.

        vault.deposit(amount0, amount1);

        vm.stopPrank();

        // #endregion deposit.

        assertEq(IERC20(USDC).balanceOf(address(this)), 0);
        assertEq(IERC20(WETH).balanceOf(address(this)), 0);

        vm.expectRevert(IArrakisMetaVault.OnlyOwner.selector);
        vm.prank(caller);
        vault.withdraw(PIPS, receiver);
    }

    function testWithdraw() public {
        address caller =
            vm.addr(uint256(keccak256(abi.encode("Caller"))));
        // #region deposit.

        // #region whitelist depositor.

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));
        address[] memory depositors = new address[](1);
        depositors[0] = depositor;

        address[] memory currentDepositors = vault.depositors();

        assertEq(currentDepositors.length, 0);

        vault.whitelistDepositors(depositors);

        currentDepositors = vault.depositors();

        assertEq(currentDepositors.length, 1);
        assertEq(currentDepositors[0], depositor);

        // #endregion whitelist depositor.

        uint256 amount0 = 2000e6;
        uint256 amount1 = 1e18;

        deal(USDC, address(depositor), amount0);
        deal(WETH, address(depositor), amount1);

        vm.startPrank(depositor);

        // #region approve module.

        IERC20(USDC).approve(address(module), amount0);
        IERC20(WETH).approve(address(module), amount1);

        // #endregion approve module.

        vault.deposit(amount0, amount1);

        vm.stopPrank();

        // #endregion deposit.

        assertEq(IERC20(USDC).balanceOf(address(this)), 0);
        assertEq(IERC20(WETH).balanceOf(address(this)), 0);

        vault.withdraw(PIPS, receiver);

        assertEq(IERC20(USDC).balanceOf(receiver), amount0);
        assertEq(IERC20(WETH).balanceOf(receiver), amount1);
    }

    // #endregion test withdraw.

    // #region test whitelist depositors.

    function testWhitelistDepositorOnlyOwner() public {
        address caller =
            vm.addr(uint256(keccak256(abi.encode("Caller"))));

        address[] memory depositors = new address[](0);
        vm.prank(caller);
        vm.expectRevert(IArrakisMetaVault.OnlyOwner.selector);

        vault.whitelistDepositors(depositors);
    }

    function testWhitelistDepositorAddressZero() public {
        address[] memory depositors = new address[](1);

        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisMetaVault.AddressZero.selector, "Depositor"
            )
        );

        vault.whitelistDepositors(depositors);
    }

    function testWhitelistDepositor() public {
        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));
        address[] memory depositors = new address[](1);
        depositors[0] = depositor;

        address[] memory currentDepositors = vault.depositors();

        assertEq(currentDepositors.length, 0);

        vault.whitelistDepositors(depositors);

        currentDepositors = vault.depositors();

        assertEq(currentDepositors.length, 1);
        assertEq(currentDepositors[0], depositor);
    }

    function testWhitelistDepositorAlreadyADepositor() public {
        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));
        address[] memory depositors = new address[](1);
        depositors[0] = depositor;

        address[] memory currentDepositors = vault.depositors();

        assertEq(currentDepositors.length, 0);

        vault.whitelistDepositors(depositors);

        currentDepositors = vault.depositors();

        assertEq(currentDepositors.length, 1);
        assertEq(currentDepositors[0], depositor);

        vm.expectRevert(
            IArrakisMetaVaultPrivate
                .DepositorAlreadyWhitelisted
                .selector
        );

        vault.whitelistDepositors(depositors);
    }

    // #endregion test whitelist depositors.

    // #region test blacklist depositors.

    function testBlacklistDepositorsOnlyOwner() public {
        address caller =
            vm.addr(uint256(keccak256(abi.encode("Caller"))));

        address[] memory depositors = new address[](0);
        vm.prank(caller);
        vm.expectRevert(IArrakisMetaVault.OnlyOwner.selector);

        vault.blacklistDepositors(depositors);
    }

    function testBlacklistDepositorsNotAlreadyWhitelistedDepositor()
        public
    {
        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));
        address[] memory depositors = new address[](1);
        depositors[0] = depositor;
        vm.expectRevert(
            IArrakisMetaVaultPrivate
                .NotAlreadyWhitelistedDepositor
                .selector
        );

        vault.blacklistDepositors(depositors);
    }

    function testBlacklistDepositors() public {
        // #region whitelist depositor.

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));
        address[] memory depositors = new address[](1);
        depositors[0] = depositor;

        address[] memory currentDepositors = vault.depositors();

        assertEq(currentDepositors.length, 0);

        vault.whitelistDepositors(depositors);

        currentDepositors = vault.depositors();

        assertEq(currentDepositors.length, 1);
        assertEq(currentDepositors[0], depositor);

        // #endregion whitelist depositor.

        vault.blacklistDepositors(depositors);

        currentDepositors = vault.depositors();

        assertEq(currentDepositors.length, 0);
    }

    // #endregion test blacklist depositors.

    // #region test owner.

    function testOwner() public {
        assertEq(
            vault.owner(),
            nft.ownerOf(uint256(uint160(address(vault))))
        );
    }

    // #endregion test owner.
}
