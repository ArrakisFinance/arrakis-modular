// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.20;

// import {console} from "forge-std/console.sol";

// import {TestWrapper} from "../utils/TestWrapper.sol";
// import {ArrakisMetaVaultPrivate} from "../../src/ArrakisMetaVaultPrivate.sol";
// import {IArrakisMetaVault} from "../../src/interfaces/IArrakisMetaVault.sol";
// import {PIPS} from "../../src/constants/CArrakis.sol";

// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

// import {ManagerMock} from "../mocks/ManagerMock.sol";
// import {LpModuleMock} from "../mocks/LpModuleMock.sol";
// import {BuggyLpModuleMock} from "../mocks/BuggyLpModule.sol";

// import {FullMath} from "@v3-lib-0.8/contracts/FullMath.sol";
// import {Ownable} from "@solady/contracts/auth/Ownable.sol";

// contract ArrakisMetaVaultPrivateTest is TestWrapper {
//     // #region constant properties.

//     address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
//     address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

//     // #endregion constant properties.

//     ArrakisMetaVaultPrivate public vault;
//     ManagerMock public manager;
//     LpModuleMock public module;
//     address public owner;

//     function setUp() public {
//         manager = new ManagerMock();
//         module = new LpModuleMock(USDC, WETH, address(manager));
//         owner = vm.addr(1);

//         vault = new ArrakisMetaVaultPrivate(USDC, WETH, owner, address(module));
//     }

//     // #region test constructor.

//     function testConstructorToken0IsAddressZero() public {
//         vm.expectRevert(
//             abi.encodeWithSelector(
//                 IArrakisMetaVault.AddressZero.selector,
//                 "Token 0"
//             )
//         );

//         vault = new ArrakisMetaVaultPrivate(
//             address(0),
//             WETH,
//             owner,
//             address(module)
//         );
//     }

//     function testConstructorToken1IsAddressZero() public {
//         vm.expectRevert(
//             abi.encodeWithSelector(
//                 IArrakisMetaVault.AddressZero.selector,
//                 "Token 1"
//             )
//         );

//         vault = new ArrakisMetaVaultPrivate(
//             USDC,
//             address(0),
//             owner,
//             address(module)
//         );
//     }

//     function testConstructorToken0GtToken1() public {
//         vm.expectRevert(IArrakisMetaVault.Token0GtToken1.selector);

//         vault = new ArrakisMetaVaultPrivate(WETH, USDC, owner, address(module));
//     }

//     function testConstructorOwnerIsAddressZero() public {
//         vm.expectRevert(
//             abi.encodeWithSelector(
//                 IArrakisMetaVault.AddressZero.selector,
//                 "Owner"
//             )
//         );

//         vault = new ArrakisMetaVaultPrivate(
//             USDC,
//             WETH,
//             address(0),
//             address(module)
//         );
//     }

//     function testConstructorModuleIsAddressZero() public {
//         vm.expectRevert(
//             abi.encodeWithSelector(
//                 IArrakisMetaVault.AddressZero.selector,
//                 "Module"
//             )
//         );

//         vault = new ArrakisMetaVaultPrivate(USDC, WETH, owner, address(0));
//     }

//     // #endregion test constructor.

//     // #region test setManager functions.

//     function testSetManagerOnlyOwner() public {
//         address caller = vm.addr(2);

//         vm.prank(caller);

//         vm.expectRevert(0x82b42900);

//         vault.setManager(address(manager));
//     }

//     function testSetManager() public {
//         vm.prank(owner);

//         vault.setManager(address(manager));
//     }

//     // #endregion test setManager functions.

//     // #region test setModule functions.

//     function testSetModuleOnlyManager() public {
//         // #region set manager.

//         vm.prank(owner);

//         vault.setManager(address(manager));

//         // #endregion set manager.

//         address caller = vm.addr(2);

//         vm.prank(caller);

//         bytes[] memory payloads = new bytes[](0);

//         vm.expectRevert(
//             abi.encodeWithSelector(
//                 IArrakisMetaVault.OnlyManager.selector,
//                 caller,
//                 address(manager)
//             )
//         );

//         vault.setModule(address(module), payloads);
//     }

//     function testSetModuleSameModule() public {
//         // #region set manager.

//         vm.prank(owner);

//         vault.setManager(address(manager));

//         // #endregion set manager.

//         vm.prank(address(manager));

//         vm.expectRevert(IArrakisMetaVault.SameModule.selector);

//         bytes[] memory payloads = new bytes[](0);

//         vault.setModule(address(module), payloads);
//     }

//     function testSetModuleNotWhitelistedModule() public {
//         // #region set manager.

//         vm.prank(owner);

//         vault.setManager(address(manager));

//         // #endregion set manager.

//         address newModule = vm.addr(3);

//         vm.prank(address(manager));

//         vm.expectRevert(
//             abi.encodeWithSelector(
//                 IArrakisMetaVault.NotWhitelistedModule.selector,
//                 newModule
//             )
//         );

//         bytes[] memory payloads = new bytes[](0);

//         vault.setModule(newModule, payloads);
//     }

//     function testSetModuleBuggyModule() public {
//         BuggyLpModuleMock buggymodule = new BuggyLpModuleMock(
//             USDC,
//             WETH,
//             address(manager)
//         );

//         vault = new ArrakisMetaVaultPrivate(
//             USDC,
//             WETH,
//             owner,
//             address(buggymodule)
//         );

//         // #region set manager.

//         vm.prank(owner);

//         vault.setManager(address(manager));

//         // #endregion set manager.

//         // #region mock manager.

//         uint256 managerBalance0 = 2000e6;
//         uint256 managerBalance1 = 1e18;

//         buggymodule.setManagerBalances(managerBalance0, managerBalance1);

//         deal(USDC, address(buggymodule), managerBalance0 * 101);
//         deal(WETH, address(buggymodule), managerBalance1 * 101);

//         // #endregion mock manager.

//         address newModule = address(
//             new LpModuleMock(USDC, WETH, address(manager))
//         );

//         // #region whitelist module.

//         vm.prank(owner);

//         address[] memory modules = new address[](1);

//         modules[0] = newModule;

//         vault.whitelistModules(modules);

//         // #endregion whitelist module.

//         (uint256 amount0, uint256 amount1) = buggymodule.totalUnderlying();

//         vm.prank(address(manager));

//         vm.expectRevert(
//             abi.encodeWithSelector(
//                 IArrakisMetaVault.ModuleNotEmpty.selector,
//                 amount0 / 2,
//                 amount1 / 2
//             )
//         );

//         bytes[] memory payloads = new bytes[](0);

//         vault.setModule(newModule, payloads);
//     }

//     function testSetModule() public {
//         // #region set manager.

//         vm.prank(owner);

//         vault.setManager(address(manager));

//         // #endregion set manager.

//         // #region mock manager.

//         uint256 managerBalance0 = 2000e6;
//         uint256 managerBalance1 = 1e18;

//         module.setManagerBalances(managerBalance0, managerBalance1);

//         deal(USDC, address(module), managerBalance0 * 101);
//         deal(WETH, address(module), managerBalance1 * 101);

//         // #endregion mock manager.

//         address newModule = address(
//             new LpModuleMock(USDC, WETH, address(manager))
//         );

//         // #region whitelist module.

//         vm.prank(owner);

//         address[] memory modules = new address[](1);

//         modules[0] = newModule;

//         vault.whitelistModules(modules);

//         // #endregion whitelist module.

//         // #region get manager, old and new module balances.

//         assertEq(IERC20(USDC).balanceOf(address(manager)), 0);
//         assertEq(IERC20(WETH).balanceOf(address(manager)), 0);

//         assertEq(
//             IERC20(USDC).balanceOf(address(module)),
//             managerBalance0 * 101
//         );
//         assertEq(
//             IERC20(WETH).balanceOf(address(module)),
//             managerBalance1 * 101
//         );

//         assertEq(IERC20(USDC).balanceOf(address(newModule)), 0);
//         assertEq(IERC20(WETH).balanceOf(address(newModule)), 0);

//         // #endregion get manager, old and new module balances.

//         vm.prank(address(manager));

//         bytes[] memory payloads = new bytes[](0);

//         vault.setModule(newModule, payloads);

//         // #region get manager, old and new module balances.

//         assertEq(IERC20(USDC).balanceOf(address(manager)), managerBalance0);
//         assertEq(IERC20(WETH).balanceOf(address(manager)), managerBalance1);

//         assertEq(IERC20(USDC).balanceOf(address(module)), 0);
//         assertEq(IERC20(WETH).balanceOf(address(module)), 0);

//         assertEq(IERC20(USDC).balanceOf(newModule), managerBalance0 * 100);
//         assertEq(IERC20(WETH).balanceOf(newModule), managerBalance1 * 100);

//         // #endregion get manager, old and new module balances.
//     }

//     // #endregion test setModule functions.

//     // #region test whitelist modules.

//     function testWhitelistModulesOnlyOwner() public {
//         address newModule = address(
//             new LpModuleMock(USDC, WETH, address(manager))
//         );

//         address[] memory modules = new address[](1);

//         modules[0] = newModule;

//         vm.expectRevert(0x82b42900);

//         vault.whitelistModules(modules);
//     }

//     function testWhitelistModulesAlreadyWhitelisted() public {
//         address[] memory modules = new address[](1);

//         modules[0] = address(module);

//         vm.expectRevert(
//             abi.encodeWithSelector(
//                 IArrakisMetaVault.AlreadyWhitelisted.selector,
//                 address(module)
//             )
//         );
//         vm.prank(owner);

//         vault.whitelistModules(modules);
//     }

//     function testWhitelistModules() public {
//         address newModule = address(
//             new LpModuleMock(USDC, WETH, address(manager))
//         );

//         address newModule2 = address(
//             new LpModuleMock(USDC, WETH, address(manager))
//         );

//         address[] memory modules = new address[](2);

//         modules[0] = newModule;
//         modules[1] = newModule2;

//         vm.prank(owner);

//         vault.whitelistModules(modules);

//         address[] memory listOfVault = vault.whitelistedModules();

//         assertEq(listOfVault[0], address(module));
//         assertEq(listOfVault[1], newModule);
//         assertEq(listOfVault[2], newModule2);
//     }

//     // #endregion test whitelist modules.

//     // #region test blacklist modules.

//     function testBlacklistModulesOnlyOwner() public {
//         address newModule = address(
//             new LpModuleMock(USDC, WETH, address(manager))
//         );

//         address[] memory modules = new address[](1);

//         modules[0] = newModule;

//         vm.prank(owner);

//         vault.whitelistModules(modules);

//         address[] memory listOfVault = vault.whitelistedModules();

//         assertEq(listOfVault[0], address(module));
//         assertEq(listOfVault[1], newModule);

//         vm.expectRevert(0x82b42900);

//         vault.blacklistModules(modules);
//     }

//     function testBlacklistModulesNotWhitelisted() public {
//         address newModule = address(
//             new LpModuleMock(USDC, WETH, address(manager))
//         );

//         address[] memory modules = new address[](1);

//         modules[0] = newModule;

//         vm.expectRevert(
//             abi.encodeWithSelector(
//                 IArrakisMetaVault.NotWhitelistedModule.selector,
//                 address(newModule)
//             )
//         );

//         vm.prank(owner);

//         vault.blacklistModules(modules);
//     }

//     function testBlacklistModulesActiveModule() public {
//         address[] memory modules = new address[](1);

//         modules[0] = address(module);

//         vm.expectRevert(IArrakisMetaVault.ActiveModule.selector);

//         vm.prank(owner);

//         vault.blacklistModules(modules);
//     }

//     function testBlacklistModules() public {
//         address newModule = address(
//             new LpModuleMock(USDC, WETH, address(manager))
//         );

//         address[] memory modules = new address[](1);

//         modules[0] = newModule;

//         vm.prank(owner);

//         vault.whitelistModules(modules);

//         address[] memory listOfVault = vault.whitelistedModules();

//         assertEq(listOfVault[0], address(module));
//         assertEq(listOfVault[1], newModule);
//         assertEq(listOfVault.length, 2);

//         vm.prank(owner);

//         vault.blacklistModules(modules);

//         listOfVault = vault.whitelistedModules();

//         assertEq(listOfVault[0], address(module));
//         assertEq(listOfVault.length, 1);
//     }

//     // #endregion test blacklist modules.

//     // #region test whitelisted modules.

//     function testWhitelistedModules() public {
//         address newModule = address(
//             new LpModuleMock(USDC, WETH, address(manager))
//         );

//         address newModule2 = address(
//             new LpModuleMock(USDC, WETH, address(manager))
//         );

//         address[] memory modules = new address[](2);

//         modules[0] = newModule;
//         modules[1] = newModule2;

//         vm.prank(owner);

//         vault.whitelistModules(modules);

//         address[] memory listOfVault = vault.whitelistedModules();

//         assertEq(listOfVault[0], address(module));
//         assertEq(listOfVault[1], newModule);
//         assertEq(listOfVault[2], newModule2);
//         assertEq(listOfVault.length, 3);
//     }

//     // #endregion test whitelisted modules.

//     // #region test getInits.

//     function testGetInits() public {
//         // #region mock inits.

//         uint256 i0 = 2000e6;
//         uint256 i1 = 1e18;

//         module.setInits(i0, i1);

//         // #endregion mock inits.

//         (uint256 init0, uint256 init1) = vault.getInits();

//         assertEq(init0, i0);
//         assertEq(init1, i1);
//     }

//     // #endregion test getInits.

//     // #region test totalUnderlying.

//     function testTotalUnderlying() public {
//         uint256 managerBalance0 = 2000e6;
//         uint256 managerBalance1 = 1e18;

//         module.setManagerBalances(managerBalance0, managerBalance1);

//         deal(USDC, address(module), managerBalance0 * 101);
//         deal(WETH, address(module), managerBalance1 * 101);

//         (uint256 amount0, uint256 amount1) = vault.totalUnderlying();

//         assertEq(managerBalance0 * 100, amount0);
//         assertEq(managerBalance1 * 100, amount1);
//     }

//     // #endregion test totalUnderlying.

//     // #region test totalUnderlyingAtPrice.

//     function testTotalUnderlyingAtPrice() public {
//         uint256 managerBalance0 = 2000e6;
//         uint256 managerBalance1 = 1e18;

//         module.setManagerBalances(managerBalance0, managerBalance1);

//         deal(USDC, address(module), managerBalance0 * 101);
//         deal(WETH, address(module), managerBalance1 * 101);

//         uint256 amt0 = managerBalance0 * 100;
//         uint256 amt1 = managerBalance1 * 100;

//         uint256 currentPriceX96 = FullMath.mulDiv(amt0, amt1, 1e18);
//         uint256 priceX96 = FullMath.mulDiv(currentPriceX96, 110, 100);

//         amt0 = FullMath.mulDiv(amt0, priceX96, currentPriceX96);
//         amt1 = FullMath.mulDiv(amt1, currentPriceX96, priceX96);

//         (uint256 amount0, uint256 amount1) = vault.totalUnderlyingAtPrice(
//             SafeCast.toUint160(priceX96)
//         );

//         assertEq(amount0, amt0);
//         assertEq(amount1, amt1);
//     }

//     // #endregion test totalUnderlyingAtPrice.

//     // #region test deposit.

//     function testDepositNotOwner() public {
//         // #region mock.

//         uint256 i0 = 2000e6;
//         uint256 i1 = 1e18;

//         module.setInits(i0, i1);

//         // #endregion mock.

//         uint256 proportion = PIPS / 2;

//         // #region get total underlying.

//         (uint256 total0, uint256 total1) = vault.totalUnderlying();

//         (total0, total1) = vault.getInits();

//         // #endregion get total underlying.

//         uint256 expectedAmount0 = FullMath.mulDiv(total0, proportion, PIPS);
//         uint256 expectedAmount1 = FullMath.mulDiv(total1, proportion, PIPS);

//         // #region approve module.

//         IERC20(USDC).approve(address(module), expectedAmount0);
//         IERC20(WETH).approve(address(module), expectedAmount1);

//         // #endregion approve module.

//         vm.expectRevert(Ownable.Unauthorized.selector);

//         vault.deposit(proportion);
//     }

//     function testDeposit() public {
//         // #region mock.

//         uint256 i0 = 2000e6;
//         uint256 i1 = 1e18;

//         module.setInits(i0, i1);

//         // #endregion mock.

//         uint256 proportion = PIPS / 2;

//         // #region get total underlying.

//         (uint256 total0, uint256 total1) = vault.totalUnderlying();

//         (total0, total1) = vault.getInits();

//         // #endregion get total underlying.

//         uint256 expectedAmount0 = FullMath.mulDiv(total0, proportion, PIPS);
//         uint256 expectedAmount1 = FullMath.mulDiv(total1, proportion, PIPS);

//         // #region approve module.

//         deal(USDC, owner, expectedAmount0);
//         deal(WETH, owner, expectedAmount1);

//         vm.startPrank(owner);

//         IERC20(USDC).approve(address(module), expectedAmount0);
//         IERC20(WETH).approve(address(module), expectedAmount1);

//         // #endregion approve module.

//         vault.deposit(proportion);

//         vm.stopPrank();
//     }

//     // #endregion test deposit.

//     // #region test withdraw.

//     function testWithdrawNotOwner() public {
//         // #region deposit first.

//         uint256 i0 = 2000e6;
//         uint256 i1 = 1e18;

//         module.setInits(i0, i1);

//         uint256 proportion = PIPS / 2;

//         // #region get total underlying.

//         (uint256 total0, uint256 total1) = vault.totalUnderlying();

//         (total0, total1) = vault.getInits();

//         // #endregion get total underlying.

//         uint256 expectedAmount0 = FullMath.mulDiv(total0, proportion, PIPS);
//         uint256 expectedAmount1 = FullMath.mulDiv(total1, proportion, PIPS);

//         // #region approve module.

//         deal(USDC, owner, expectedAmount0);
//         deal(WETH, owner, expectedAmount1);

//         vm.startPrank(owner);

//         IERC20(USDC).approve(address(module), expectedAmount0);
//         IERC20(WETH).approve(address(module), expectedAmount1);

//         // #endregion approve module.

//         vault.deposit(proportion);

//         vm.stopPrank();

//         // #endregion deposit first.

//         vm.expectRevert(Ownable.Unauthorized.selector);

//         vault.withdraw(PIPS, owner);
//     }

//     function testWithdraw() public {
//         // #region deposit first.

//         uint256 i0 = 2000e6;
//         uint256 i1 = 1e18;

//         module.setInits(i0, i1);

//         uint256 proportion = PIPS / 2;

//         // #region get total underlying.

//         (uint256 total0, uint256 total1) = vault.totalUnderlying();

//         (total0, total1) = vault.getInits();

//         // #endregion get total underlying.

//         uint256 expectedAmount0 = FullMath.mulDiv(total0, proportion, PIPS);
//         uint256 expectedAmount1 = FullMath.mulDiv(total1, proportion, PIPS);

//         // #region approve module.

//         deal(USDC, owner, expectedAmount0);
//         deal(WETH, owner, expectedAmount1);

//         vm.startPrank(owner);

//         IERC20(USDC).approve(address(module), expectedAmount0);
//         IERC20(WETH).approve(address(module), expectedAmount1);

//         // #endregion approve module.

//         vault.deposit(proportion);

//         // #endregion deposit first.

//         vault.withdraw(PIPS, owner);

//         vm.stopPrank();
//     }

//     // #endregion test withdraw.
// }
